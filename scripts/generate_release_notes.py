#!/usr/bin/env python3
"""Generate the public Release Notes JSON.

Inputs and de-duplication rules are intentionally fixed:
- version/build: explicit CLI values first, then `pubspec.yaml`.
- release links: GitHub Releases for the configured repository.
- change links: merged pull requests, de-duplicated by PR number or URL.
- deploy links: explicit deploy URL and commit URL.
- extension point: `docs/ai-tool-watch/latest-report.json` is summarized when
  present, but not required.
"""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_DEFAULT = "kanta13jp1/my_web_app"
PUBSPEC_VERSION_RE = re.compile(r"^version:\s*([0-9A-Za-z.+_-]+)\s*$", re.MULTILINE)


def run_json(command: list[str]) -> Any:
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        return []
    try:
        return json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return []


def load_json(path: Path | None, default: Any) -> Any:
    if path is None or not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def parse_pubspec_version(path: Path) -> tuple[str, str]:
    if not path.exists():
        return "0.0.0", "0"
    match = PUBSPEC_VERSION_RE.search(path.read_text(encoding="utf-8"))
    if not match:
        return "0.0.0", "0"
    raw = match.group(1)
    if "+" in raw:
        version, build = raw.split("+", 1)
    else:
        version, build = raw, "0"
    return version, build


def label_names(item: dict[str, Any]) -> set[str]:
    labels = item.get("labels") or []
    names: set[str] = set()
    for label in labels:
        if isinstance(label, dict):
            names.add(str(label.get("name", "")).lower())
        else:
            names.add(str(label).lower())
    return names


def classify_change(title: str, labels: set[str]) -> str:
    lower = title.lower()
    if labels & {"bug", "fix", "ci-failure"} or any(
        token in lower for token in ("fix", "bug", "hotfix", "ci failure")
    ):
        return "fix"
    if labels & {"documentation", "docs"} or lower.startswith(("docs:", "doc:")):
        return "docs"
    if labels & {"automation", "ci"} or any(
        token in lower for token in ("ci:", "workflow", "actions", "sync", "automation")
    ):
        return "automation"
    if labels & {"security"} or "security" in lower:
        return "security"
    return "feature"


def normalize_pr(item: dict[str, Any]) -> dict[str, Any] | None:
    number = item.get("number")
    title = str(item.get("title") or "").strip()
    url = str(item.get("url") or "").strip()
    if not title and not url:
        return None
    labels = label_names(item)
    summary = f"#{number} {title}".strip() if number else title
    return {
        "id": f"pr-{number}" if number else url,
        "category": classify_change(title, labels),
        "summary": summary,
        "mergedAt": item.get("mergedAt") or item.get("publishedAt") or "",
        "links": [
            {
                "type": "pull_request",
                "title": f"PR #{number}" if number else "Pull request",
                "url": url,
            }
        ]
        if url
        else [],
    }


def collect_pull_requests(args: argparse.Namespace) -> list[dict[str, Any]]:
    data = load_json(args.pull_requests_json, None)
    if data is None:
        data = run_json(
            [
                "gh",
                "pr",
                "list",
                "--repo",
                args.repo,
                "--state",
                "merged",
                "--limit",
                str(args.max_prs),
                "--json",
                "number,title,mergedAt,url,labels",
            ]
        )
    if isinstance(data, dict):
        data = data.get("pullRequests", [])
    if not isinstance(data, list):
        data = []

    seen: set[str] = set()
    changes: list[dict[str, Any]] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        normalized = normalize_pr(item)
        if normalized is None:
            continue
        key = str(normalized.get("id") or normalized.get("links", [{}])[0].get("url"))
        if key in seen:
            continue
        seen.add(key)
        changes.append(normalized)
    changes.sort(key=lambda item: str(item.get("mergedAt") or ""), reverse=True)
    return changes[: args.max_prs]


def normalize_release(item: dict[str, Any]) -> dict[str, str] | None:
    tag = str(item.get("tagName") or item.get("tag_name") or "").strip()
    url = str(item.get("url") or "").strip()
    if not tag or not url:
        return None
    return {
        "type": "release",
        "title": str(item.get("name") or tag),
        "url": url,
    }


def collect_release_links(args: argparse.Namespace) -> list[dict[str, str]]:
    data = load_json(args.releases_json, None)
    if data is None:
        data = run_json(
            [
                "gh",
                "release",
                "list",
                "--repo",
                args.repo,
                "--limit",
                str(args.max_releases),
                "--json",
                "tagName,name,publishedAt,url,isDraft,isPrerelease",
            ]
        )
    if isinstance(data, dict):
        data = data.get("releases", [])
    if not isinstance(data, list):
        data = []

    links: list[dict[str, str]] = []
    seen: set[str] = set()
    current_tag = f"v{args.version}"
    for item in data:
        if not isinstance(item, dict) or item.get("isDraft"):
            continue
        tag = str(item.get("tagName") or item.get("tag_name") or "")
        if tag != current_tag:
            continue
        link = normalize_release(item)
        if link is None or link["url"] in seen:
            continue
        links.append(link)
        seen.add(link["url"])

    if not links:
        links.append(
            {
                "type": "release",
                "title": f"GitHub Release {current_tag}",
                "url": f"https://github.com/{args.repo}/releases/tag/{current_tag}",
            }
        )
    return links


def commit_links(args: argparse.Namespace) -> list[dict[str, str]]:
    links: list[dict[str, str]] = []
    if args.commit:
        links.append(
            {
                "type": "commit",
                "title": args.commit[:12],
                "url": f"https://github.com/{args.repo}/commit/{args.commit}",
            }
        )
    if args.deploy_url:
        links.append({"type": "deploy", "title": "Production deploy", "url": args.deploy_url})
    return links


def summarize_ai_tool_watch(path: Path) -> dict[str, Any] | None:
    data = load_json(path, None)
    if not isinstance(data, dict):
        return None
    signals = data.get("signals") or data.get("latest_signals") or []
    changed = data.get("changed_sources") or data.get("changed") or []
    return {
        "source": path.as_posix(),
        "signalCount": len(signals) if isinstance(signals, list) else 0,
        "changedSourceCount": len(changed) if isinstance(changed, list) else 0,
    }


def build_release_notes(args: argparse.Namespace) -> dict[str, Any]:
    version, build = parse_pubspec_version(args.pubspec)
    args.version = args.version or version
    args.build = args.build or build
    release_date = args.date or dt.datetime.now(dt.UTC).date().isoformat()
    generated_at = args.generated_at or f"{release_date}T00:00:00Z"

    changes = collect_pull_requests(args)
    categories = sorted({str(item["category"]) for item in changes})
    release_links = collect_release_links(args)
    links = release_links + commit_links(args)
    ai_tool_watch = summarize_ai_tool_watch(args.ai_tool_watch)

    return {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "source": {
            "repo": args.repo,
            "pubspec": args.pubspec.as_posix(),
            "aiToolWatch": args.ai_tool_watch.as_posix(),
        },
        "current": {
            "version": args.version,
            "build": args.build,
            "date": release_date,
            "category": "release",
            "summary": f"Release {args.version}",
            "links": links,
        },
        "versions": [
            {
                "version": args.version,
                "build": args.build,
                "date": release_date,
                "category": "release",
                "summary": f"Release {args.version}",
                "links": links,
                "changeCategories": categories,
                "changes": changes,
                "extensions": {
                    "aiToolWatch": ai_tool_watch,
                },
            }
        ],
    }


def render_json(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def check_output(path: Path, expected: str) -> int:
    if not path.exists():
        print(f"::error::{path} does not exist. Generate release notes first.", file=sys.stderr)
        return 1
    actual = path.read_text(encoding="utf-8")
    if actual == expected:
        print(f"{path} is up to date")
        return 0
    diff = difflib.unified_diff(
        actual.splitlines(keepends=True),
        expected.splitlines(keepends=True),
        fromfile=str(path),
        tofile=f"{path} (generated)",
    )
    print("".join(diff), file=sys.stderr)
    print(f"::error::{path} is out of date. Run scripts/generate_release_notes.py.", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=REPO_DEFAULT)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--output", type=Path, default=Path("web/release-notes.json"))
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--date")
    parser.add_argument("--generated-at")
    parser.add_argument("--commit")
    parser.add_argument("--deploy-url")
    parser.add_argument("--max-prs", type=int, default=30)
    parser.add_argument("--max-releases", type=int, default=10)
    parser.add_argument("--pull-requests-json", type=Path)
    parser.add_argument("--releases-json", type=Path)
    parser.add_argument(
        "--ai-tool-watch",
        type=Path,
        default=Path("docs/ai-tool-watch/latest-report.json"),
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    data = build_release_notes(args)
    rendered = render_json(data)
    if args.check:
        return check_output(args.output, rendered)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
