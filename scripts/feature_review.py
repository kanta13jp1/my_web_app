#!/usr/bin/env python3
"""Hourly feature review job.

Reviews one feature per hourly cron run, or selected/all features via
workflow_dispatch, then opens deduplicated GitHub Issues for actionable
findings.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


LOG_PATH = Path("/tmp/feature-review.log")
SUMMARY_PATH = Path("/tmp/feature-review-summary.json")
SCREENSHOT_DIR = Path("/tmp/feature-review-screenshots")

TITLE_HASH_RE = re.compile(r"\[review:([a-f0-9]{6,16})\]", re.IGNORECASE)
TODO_RE = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b", re.IGNORECASE)


def configure_stdout() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")


def log(message: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    timestamp = dt.datetime.now(dt.timezone.utc).isoformat()
    line = f"[{timestamp}] {message}"
    print(line)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def load_config(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def all_features(config: dict[str, Any]) -> list[dict[str, Any]]:
    targets = config.get("review_targets", {})
    pages = [{**item, "kind": "page"} for item in targets.get("pages", [])]
    edge_functions = [
        {**item, "kind": "edge_function"}
        for item in targets.get("edge_functions", [])
    ]
    return pages + edge_functions


def select_feature_for_this_hour(
    config: dict[str, Any],
    hour_override: int | None = None,
) -> str | None:
    rotation = config.get("rotation", {})
    feature_order = rotation.get("feature_order", [])
    if not feature_order:
        return None
    utc_hour = hour_override
    if utc_hour is None:
        utc_hour = dt.datetime.now(dt.timezone.utc).hour
    return feature_order[int(utc_hour) % len(feature_order)]


def issue_title_hash(
    feature_slug: str,
    category: str,
    summary: str,
    length: int = 8,
) -> str:
    key = f"{feature_slug}|{category}|{summary[:80]}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:length]


def run_command(
    args: list[str],
    cwd: Path,
    timeout: int = 45,
) -> dict[str, Any]:
    try:
        completed = subprocess.run(
            args,
            cwd=cwd,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        return {
            "ok": completed.returncode == 0,
            "returncode": completed.returncode,
            "stdout": completed.stdout[-6000:],
            "stderr": completed.stderr[-6000:],
        }
    except FileNotFoundError as error:
        return {"ok": False, "returncode": 127, "stdout": "", "stderr": str(error)}
    except subprocess.TimeoutExpired as error:
        return {
            "ok": False,
            "returncode": 124,
            "stdout": (error.stdout or "")[-6000:] if isinstance(error.stdout, str) else "",
            "stderr": f"timeout after {timeout}s",
        }


def read_source_summary(source: str, repo_root: Path) -> dict[str, Any]:
    path = repo_root / source
    if not path.exists():
        return {
            "source": source,
            "exists": False,
            "error": "source file not found",
            "todos": [],
            "excerpt": "",
        }

    text = path.read_text(encoding="utf-8", errors="replace")
    todos = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        if TODO_RE.search(line):
            todos.append({"line": line_no, "text": line.strip()[:240]})
        if len(todos) >= 20:
            break

    return {
        "source": source,
        "exists": True,
        "size_bytes": len(text.encode("utf-8")),
        "line_count": text.count("\n") + 1,
        "todos": todos,
        "excerpt": text[:5000],
    }


def git_log_for_source(source: str, repo_root: Path) -> str:
    result = run_command(
        [
            "git",
            "log",
            "--since=30 days ago",
            "--pretty=format:%h %ad %s",
            "--date=short",
            "--",
            source,
        ],
        repo_root,
        timeout=20,
    )
    return result["stdout"].strip()


def load_analyze_cache(repo_root: Path) -> dict[str, Any]:
    cache_path = repo_root / "docs" / "flutter-analyze-cache.json"
    if not cache_path.exists():
        return {"exists": False}
    try:
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        return {"exists": True, "data_preview": json.dumps(data, ensure_ascii=False)[:4000]}
    except Exception as error:  # noqa: BLE001
        return {"exists": True, "error": str(error)}


def collect_page_signals(
    page_config: dict[str, Any],
    production_url: str,
    repo_root: Path,
    timeout_seconds: int,
    skip_playwright: bool = False,
) -> dict[str, Any]:
    slug = page_config["slug"]
    url = production_url.rstrip("/") + page_config.get("path", "/")
    signals: dict[str, Any] = {
        "kind": "page",
        "feature": page_config,
        "url": url,
        "source": read_source_summary(page_config.get("source", ""), repo_root),
        "git_log": git_log_for_source(page_config.get("source", ""), repo_root),
        "analyze_cache": load_analyze_cache(repo_root),
        "playwright": {"skipped": skip_playwright},
    }

    if skip_playwright:
        return signals

    try:
        from playwright.sync_api import sync_playwright
    except Exception as error:  # noqa: BLE001
        signals["playwright"] = {"available": False, "error": str(error)}
        return signals

    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    screenshot_path = SCREENSHOT_DIR / f"{slug}.png"
    console_messages: list[str] = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch()
            page = browser.new_page(viewport={"width": 1365, "height": 768})
            page.on("console", lambda msg: console_messages.append(f"{msg.type}: {msg.text}"[:500]))
            response = page.goto(url, wait_until="networkidle", timeout=timeout_seconds * 1000)
            page.screenshot(path=str(screenshot_path), full_page=True)
            html = page.locator("body").inner_text(timeout=3000)
            dom_metrics = page.evaluate(
                """() => ({
                  title: document.title,
                  h1: Array.from(document.querySelectorAll('h1')).map(e => e.textContent?.trim()).filter(Boolean).slice(0, 5),
                  buttons: document.querySelectorAll('button, [role="button"], a').length,
                  imagesMissingAlt: Array.from(document.querySelectorAll('img')).filter(img => !img.getAttribute('alt')).length,
                  horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 2
                })""",
            )
            browser.close()

        signals["playwright"] = {
            "available": True,
            "status": response.status if response else None,
            "console": console_messages[-20:],
            "body_text_preview": html[:5000],
            "dom_metrics": dom_metrics,
            "screenshot_path": str(screenshot_path),
        }
    except Exception as error:  # noqa: BLE001
        signals["playwright"] = {
            "available": True,
            "error": f"{type(error).__name__}: {error}",
            "console": console_messages[-20:],
        }

    return signals


def collect_ef_signals(
    ef_config: dict[str, Any],
    repo_root: Path,
) -> dict[str, Any]:
    source = ef_config.get("source", "")
    lint_result = {"ok": False, "stderr": "source missing"}
    if source:
        lint_result = run_command(
            [
                "deno",
                "lint",
                "--config",
                "supabase/functions/deno.json",
                source,
            ],
            repo_root,
            timeout=60,
        )
    return {
        "kind": "edge_function",
        "feature": ef_config,
        "source": read_source_summary(source, repo_root),
        "git_log": git_log_for_source(source, repo_root),
        "deno_lint": lint_result,
    }


def compact_signals(signals: dict[str, Any]) -> dict[str, Any]:
    compact = json.loads(json.dumps(signals, ensure_ascii=False, default=str))
    source = compact.get("source", {})
    if isinstance(source, dict) and "excerpt" in source:
        source["excerpt"] = source["excerpt"][:2500]
    playwright = compact.get("playwright", {})
    if isinstance(playwright, dict):
        if "body_text_preview" in playwright:
            playwright["body_text_preview"] = playwright["body_text_preview"][:2500]
        if "console" in playwright:
            playwright["console"] = playwright["console"][-10:]
    return compact


def parse_json_findings(raw_text: str) -> list[dict[str, Any]]:
    cleaned = raw_text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    parsed = json.loads(cleaned)
    if isinstance(parsed, list):
        findings = parsed
    else:
        findings = parsed.get("findings", [])
    if not isinstance(findings, list):
        return []
    return [item for item in findings if isinstance(item, dict)]


def image_block_for_screenshot(path_value: str | None) -> dict[str, Any] | None:
    if not path_value:
        return None
    path = Path(path_value)
    if not path.exists() or path.stat().st_size > 4_000_000:
        return None
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return {
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": "image/png",
            "data": encoded,
        },
    }


def claude_review(
    signals: dict[str, Any],
    feature_config: dict[str, Any],
    claude_config: dict[str, Any],
    skip_ai: bool = False,
) -> list[dict[str, Any]]:
    if skip_ai or not os.getenv("ANTHROPIC_API_KEY"):
        return heuristic_findings(signals, feature_config)

    try:
        from anthropic import Anthropic
    except Exception as error:  # noqa: BLE001
        log(f"[WARN] anthropic package unavailable; heuristic fallback: {error}")
        return heuristic_findings(signals, feature_config)

    model = os.getenv("ANTHROPIC_MODEL") or claude_config.get("model", "claude-haiku-4-5")
    max_findings = int(claude_config.get("max_findings_per_feature", 3))
    prompt = {
        "feature": feature_config,
        "signals": compact_signals(signals),
        "allowed_categories": feature_config.get("review_categories", []),
        "required_json_schema": {
            "findings": [
                {
                    "category": "ui_bug|a11y|stale_todo|dead_code|outdated_docs|lint_warning|performance",
                    "severity": "low|medium|high",
                    "summary": "short issue title summary",
                    "review_text": "evidence from signals",
                    "recommendation": "concrete fix",
                }
            ]
        },
    }
    content: list[dict[str, Any]] = [{
        "type": "text",
        "text": (
            "Review this feature for actionable product or engineering issues. "
            f"Return JSON only with at most {max_findings} findings. "
            "Skip subjective polish, duplicates, and issues without clear evidence.\n\n"
            f"<<<USER_DATA>>>\n{json.dumps(prompt, ensure_ascii=False)[:24000]}\n<<<END>>>"
        ),
    }]
    screenshot = signals.get("playwright", {}).get("screenshot_path") if isinstance(signals.get("playwright"), dict) else None
    image_block = image_block_for_screenshot(screenshot)
    if image_block:
        content.append(image_block)

    retry_count = int(claude_config.get("max_retry", 3) or 3)
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    for attempt in range(1, retry_count + 1):
        try:
            response = client.messages.create(
                model=model,
                max_tokens=1200,
                temperature=0,
                system=claude_config.get("system_prompt_addition", ""),
                messages=[{"role": "user", "content": content}],
            )
            raw_text = "\n".join(
                getattr(part, "text", "")
                for part in response.content
                if getattr(part, "type", "") == "text"
            )
            findings = parse_json_findings(raw_text)
            return normalize_findings(findings, feature_config, max_findings)
        except Exception as error:  # noqa: BLE001
            log(f"[WARN] Claude review attempt {attempt}/{retry_count} failed: {error}")
            if attempt < retry_count:
                time.sleep(min(8, 2 ** attempt))

    return heuristic_findings(signals, feature_config)


def heuristic_findings(
    signals: dict[str, Any],
    feature_config: dict[str, Any],
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    source = signals.get("source", {})
    if isinstance(source, dict):
        todos = source.get("todos", [])
        if todos:
            first = todos[0]
            findings.append({
                "category": "stale_todo",
                "severity": "low",
                "summary": f"{feature_config['slug']} has unresolved TODO/FIXME markers",
                "review_text": f"Detected {len(todos)} TODO-like markers. First: line {first.get('line')}: {first.get('text')}",
                "recommendation": "Review whether the TODO is still actionable; either fix it or convert it into a tracked issue.",
            })

    if signals.get("kind") == "edge_function":
        lint = signals.get("deno_lint", {})
        if isinstance(lint, dict) and not lint.get("ok", False):
            findings.append({
                "category": "lint_warning",
                "severity": "medium",
                "summary": f"{feature_config['slug']} has Deno lint failures",
                "review_text": (lint.get("stderr") or lint.get("stdout") or "deno lint failed")[:1200],
                "recommendation": "Run deno lint locally, fix the reported rule violations, and add a regression check when applicable.",
            })

    if signals.get("kind") == "page":
        playwright = signals.get("playwright", {})
        if isinstance(playwright, dict):
            metrics = playwright.get("dom_metrics") or {}
            if isinstance(metrics, dict) and metrics.get("horizontalOverflow"):
                findings.append({
                    "category": "ui_bug",
                    "severity": "medium",
                    "summary": f"{feature_config['slug']} page appears to overflow horizontally",
                    "review_text": "Playwright DOM metrics reported document scrollWidth greater than clientWidth.",
                    "recommendation": "Inspect responsive constraints and long text/buttons on the page, then verify at mobile and desktop widths.",
                })
            if isinstance(metrics, dict) and int(metrics.get("imagesMissingAlt") or 0) > 0:
                findings.append({
                    "category": "a11y",
                    "severity": "low",
                    "summary": f"{feature_config['slug']} page has images without alt text",
                    "review_text": f"Detected {metrics.get('imagesMissingAlt')} image elements missing alt attributes.",
                    "recommendation": "Add meaningful alt text for content images or empty alt for decorative images.",
                })
            console = playwright.get("console") or []
            if isinstance(console, list) and any("error" in str(item).lower() for item in console):
                findings.append({
                    "category": "ui_bug",
                    "severity": "medium",
                    "summary": f"{feature_config['slug']} page logs browser console errors",
                    "review_text": "\n".join(str(item) for item in console[-5:]),
                    "recommendation": "Reproduce the page in browser and fix the underlying runtime or resource error.",
                })

    return normalize_findings(findings, feature_config, 3)


def normalize_findings(
    findings: list[dict[str, Any]],
    feature_config: dict[str, Any],
    limit: int,
) -> list[dict[str, Any]]:
    allowed_categories = set(feature_config.get("review_categories", []))
    normalized: list[dict[str, Any]] = []
    for item in findings:
        category = str(item.get("category") or "ui_bug")
        if allowed_categories and category not in allowed_categories:
            category = next(iter(allowed_categories))
        severity = str(item.get("severity") or "medium")
        if severity not in {"low", "medium", "high"}:
            severity = "medium"
        summary = str(item.get("summary") or "").strip()
        if not summary:
            continue
        normalized.append({
            "feature_slug": feature_config["slug"],
            "source": feature_config.get("source", ""),
            "priority": feature_config.get("priority", ""),
            "category": category,
            "severity": severity,
            "summary": summary[:180],
            "review_text": str(item.get("review_text") or item.get("evidence") or "")[:2500],
            "recommendation": str(item.get("recommendation") or "")[:1500],
        })
    return normalized[:limit]


def github_request(
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
) -> Any:
    token = os.getenv("GITHUB_TOKEN", "")
    repository = os.getenv("GITHUB_REPOSITORY", "")
    if not token or not repository:
        raise RuntimeError("GITHUB_TOKEN and GITHUB_REPOSITORY are required")
    url = f"https://api.github.com/repos/{repository}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API {method} {path} failed: {error.code} {detail}") from error


def extract_hashes(issues: list[dict[str, Any]]) -> set[str]:
    hashes: set[str] = set()
    for issue in issues:
        title = str(issue.get("title", ""))
        match = TITLE_HASH_RE.search(title)
        if match:
            hashes.add(match.group(1).lower())
    return hashes


def existing_issue_hashes(recent_closed_days: int) -> set[str]:
    if not os.getenv("GITHUB_TOKEN") or not os.getenv("GITHUB_REPOSITORY"):
        log("[WARN] GitHub env missing; de-dupe uses empty issue set")
        return set()

    hashes: set[str] = set()
    open_issues = github_request(
        "GET",
        "/issues?state=open&labels=auto-review&per_page=100",
    )
    hashes |= extract_hashes(open_issues or [])

    since = (
        dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=recent_closed_days)
    ).isoformat().replace("+00:00", "Z")
    closed_issues = github_request(
        "GET",
        "/issues?state=closed&labels=auto-review&per_page=100&since="
        + urllib.parse.quote(since),
    )
    hashes |= extract_hashes(closed_issues or [])
    return hashes


def ensure_label(name: str, color: str, description: str, dry_run: bool) -> None:
    if dry_run or not os.getenv("GITHUB_TOKEN") or not os.getenv("GITHUB_REPOSITORY"):
        return
    try:
        github_request("GET", f"/labels/{urllib.parse.quote(name, safe='')}")
    except Exception:
        try:
            github_request("POST", "/labels", {
                "name": name,
                "color": color,
                "description": description[:100],
            })
        except Exception as error:  # noqa: BLE001
            log(f"[WARN] label create failed for {name}: {error}")


def issue_title(finding: dict[str, Any], template: dict[str, Any]) -> str:
    prefix = template.get("title_prefix", "[review:{hash}]").format(hash=finding["hash"])
    return f"{prefix} {finding['feature_slug']} {finding['summary']}"[:240]


def issue_body(
    finding: dict[str, Any],
    template: dict[str, Any],
    signals_summary: str,
) -> str:
    body_format = template.get("body_format", "{summary}")
    values = {
        **finding,
        "signals_summary": signals_summary,
    }
    return body_format.format(**values)


def create_issue(
    finding: dict[str, Any],
    template: dict[str, Any],
    dry_run: bool,
    signals_summary: str,
) -> bool:
    severity = finding["severity"]
    category = finding["category"]
    feature_slug = finding["feature_slug"]
    labels = list(template.get("labels", ["auto-review"]))
    labels.extend([
        template.get("severity_label_format", "severity:{severity}").format(severity=severity),
        template.get("feature_label_format", "feature:{feature_slug}").format(feature_slug=feature_slug),
        template.get("category_label_format", "category:{category}").format(category=category),
    ])

    for label in labels:
        color = "ededed"
        if label == "auto-review":
            color = "5319e7"
        elif label.startswith("severity:high"):
            color = "b60205"
        elif label.startswith("severity:medium"):
            color = "fbca04"
        elif label.startswith("severity:low"):
            color = "0e8a16"
        ensure_label(label, color, "Created by feature-review automation", dry_run)

    title = issue_title(finding, template)
    body = issue_body(finding, template, signals_summary)
    if dry_run:
        log(f"[DRY-RUN] would create issue: {title} labels={labels}")
        return True

    github_request("POST", "/issues", {"title": title, "body": body, "labels": labels})
    log(f"[OK] issue created: {title}")
    return True


def signals_summary(signals: dict[str, Any]) -> str:
    compact = compact_signals(signals)
    return "```json\n" + json.dumps(compact, ensure_ascii=False, indent=2)[:6000] + "\n```"


def review_feature(
    feature: dict[str, Any],
    config: dict[str, Any],
    repo_root: Path,
    args: argparse.Namespace,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    timeout_seconds = int(config.get("throttle", {}).get("playwright_timeout_seconds", 30))
    if feature["kind"] == "page":
        signals = collect_page_signals(
            feature,
            config.get("production_url", ""),
            repo_root,
            timeout_seconds,
            skip_playwright=args.skip_playwright,
        )
    else:
        signals = collect_ef_signals(feature, repo_root)

    findings = claude_review(
        signals,
        feature,
        config.get("claude_review", {}),
        skip_ai=args.skip_ai,
    )
    return findings, signals


def resolve_targets(
    config: dict[str, Any],
    args: argparse.Namespace,
) -> list[dict[str, Any]]:
    features = all_features(config)
    by_slug = {feature["slug"]: feature for feature in features}

    if args.targets:
        wanted = [slug.strip() for slug in args.targets.split(",") if slug.strip()]
    elif args.force_full_scan:
        wanted = [feature["slug"] for feature in features]
    else:
        rotation_target = select_feature_for_this_hour(config, args.rotation_hour)
        if rotation_target is None:
            raise ValueError("rotation.feature_order is empty")
        wanted = [rotation_target]
        log(f"[INFO] rotation target = {rotation_target}")

    missing = [slug for slug in wanted if slug not in by_slug]
    if missing:
        raise ValueError(f"unknown target feature(s): {', '.join(missing)}")
    return [by_slug[slug] for slug in wanted]


def write_summary(stats: dict[str, Any]) -> None:
    SUMMARY_PATH.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    configure_stdout()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--targets", default="")
    parser.add_argument("--force-full-scan", action="store_true")
    parser.add_argument("--rotation-hour", type=int, default=None)
    parser.add_argument("--skip-ai", action="store_true")
    parser.add_argument("--skip-playwright", action="store_true")
    args = parser.parse_args(argv)

    if not args.config.exists():
        print(f"[FAIL] config not found: {args.config}", file=sys.stderr)
        return 2

    LOG_PATH.write_text("# Feature Review Log\n\n", encoding="utf-8")
    config = load_config(args.config)
    repo_root = Path(__file__).resolve().parent.parent
    stats: dict[str, Any] = {
        "new_count": 0,
        "skipped_count": 0,
        "error_count": 0,
        "reviewed_features": [],
        "details": [],
    }

    try:
        targets = resolve_targets(config, args)
    except Exception as error:  # noqa: BLE001
        log(f"[FAIL] {error}")
        stats["error_count"] += 1
        write_summary(stats)
        return 2

    dedup = config.get("dedup", {})
    throttle = config.get("throttle", {})
    hash_length = int(dedup.get("title_hash_length", 8))
    max_issues_per_run = int(throttle.get("max_issues_per_run", 3))
    max_issues_per_feature = int(throttle.get("max_issues_per_feature", 1))
    max_findings_per_feature = int(throttle.get("max_findings_per_feature", 3))
    existing_hashes = existing_issue_hashes(int(dedup.get("skip_if_recent_closed_days", 7)))

    for feature in targets:
        if stats["new_count"] >= max_issues_per_run:
            break
        stats["reviewed_features"].append(feature["slug"])
        log(f"[INFO] reviewing {feature['slug']} ({feature['kind']})")
        feature_created = 0
        try:
            findings, collected_signals = review_feature(feature, config, repo_root, args)
            for finding in findings[:max_findings_per_feature]:
                if stats["new_count"] >= max_issues_per_run:
                    break
                if feature_created >= max_issues_per_feature:
                    stats["skipped_count"] += 1
                    continue

                hash_value = issue_title_hash(
                    finding["feature_slug"],
                    finding["category"],
                    finding["summary"],
                    hash_length,
                )
                finding["hash"] = hash_value
                if hash_value in existing_hashes:
                    stats["skipped_count"] += 1
                    log(f"[SKIP] duplicate finding {hash_value}: {finding['summary']}")
                    continue

                ok = create_issue(
                    finding,
                    config["issue_template"],
                    args.dry_run,
                    signals_summary(collected_signals),
                )
                if ok:
                    stats["new_count"] += 1
                    feature_created += 1
                    existing_hashes.add(hash_value)
                else:
                    stats["error_count"] += 1
        except Exception as error:  # noqa: BLE001
            stats["error_count"] += 1
            detail = f"{feature['slug']}: {type(error).__name__}: {error}"
            stats["details"].append(detail)
            log(f"[ERROR] {detail}")

    write_summary(stats)
    log(
        "[DONE] "
        f"{stats['new_count']} new, "
        f"{stats['skipped_count']} skipped, "
        f"{stats['error_count']} errors",
    )
    return 1 if stats["error_count"] and not stats["reviewed_features"] else 0


if __name__ == "__main__":
    sys.exit(main())
