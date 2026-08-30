"""CI and deploy failure digests for GitHub Actions.

The script keeps recurring workflow failures actionable by extracting the
small part of a long log that an agent or maintainer needs next. It is
dependency-free so it can run early in CI jobs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

VERSION_RE = re.compile(r"\b\d{14}\b")
MIGRATION_FILE_RE = re.compile(r"^(\d{14})_.*\.sql$")
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
MARKER_RE = re.compile(r"<!--\s*([A-Za-z0-9_-]+):\s*(.*?)\s*-->", re.DOTALL)
NOISE_LINE_RE = re.compile(
    r"(download action|complete job name|post job cleanup|set up job|finishing:|^##\[group\])",
    re.IGNORECASE,
)
TIMESTAMP_PREFIX_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?\s+")

DEN0_KEYWORDS = (
    "error",
    "warning",
    "lint",
    "deno",
    ".ts:",
    "supabase/functions",
)

DEPLOY_KEYWORDS = (
    "error",
    "failed",
    "remote migration",
    "schema_migrations",
    "sqlstate",
    "duplicate key",
    "repair",
    "esm.sh",
    "deno",
    "supabase",
)

WORKFLOW_CATEGORY_PATTERNS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "migration-collision",
        (
            "schema_migrations_pkey",
            "duplicate key",
            "remote migration versions not found",
            "migration versions not found",
            "supabase migration repair",
        ),
    ),
    (
        "supabase-push",
        (
            "supabase db push",
            "run supabase migrations",
            "supabase migration",
            "database push",
            "db push",
        ),
    ),
    (
        "deno-lint",
        (
            "deno lint",
            "lint supabase/functions",
            "deno fmt --check",
            "deno check",
        ),
    ),
    (
        "flutter-analyze",
        (
            "flutter analyze",
            "analyze code",
            "dart analyze",
        ),
    ),
    (
        "flutter-build",
        (
            "flutter build",
            "build flutter web",
            "build web",
        ),
    ),
    (
        "notion-sync",
        (
            "notion mirror",
            "notion sync",
            "notion api",
            "notion",
        ),
    ),
)

RECOVERY_DRAFTS: dict[str, tuple[str, ...]] = {
    "migration-collision": (
        "- Compare local migration files with remote `schema_migrations` for duplicate or missing versions.",
        "- Run `supabase migration list` and repair the exact version before retrying deploy.",
        "- Re-run the failed deploy workflow after the repaired migration state is committed or confirmed.",
    ),
    "supabase-push": (
        "- Inspect the Supabase CLI error and identify whether the failure is SQL, auth, or network related.",
        "- Validate the newest migration locally, then retry `supabase db push` with the expected project credentials.",
        "- If the remote state changed, record the recovery command in the issue before re-running CI.",
    ),
    "deno-lint": (
        "- Run `deno fmt --check`, `deno lint`, and targeted Edge Function tests for the touched function.",
        "- Fix the reported TypeScript or formatting issue at the path shown in the error signature.",
        "- Re-run the same workflow after the lint/test patch is pushed.",
    ),
    "flutter-analyze": (
        "- Run `flutter pub get` and `flutter analyze` locally on a clean checkout.",
        "- Fix the analyzer diagnostic at the referenced Dart file, keeping generated plugin files out of the patch.",
        "- Re-run the CI workflow after analyzer output is clean.",
    ),
    "flutter-build": (
        "- Run the failing `flutter build` target locally with the same flavor or web flags.",
        "- Check dependency resolution, asset declarations, and generated files before changing application code.",
        "- Re-run the build workflow and attach the successful run URL.",
    ),
    "notion-sync": (
        "- Check Notion secret availability, database schema drift, and API response status from the failed log.",
        "- Update the Notion mapping or credential configuration before retrying the sync workflow.",
        "- If Notion is temporarily unavailable, leave the issue open until a later scheduled success closes it.",
    ),
    "generic-ci": (
        "- Inspect the failed step and the normalized error signature in this issue.",
        "- Reproduce the command locally or with `gh run view --log` before editing code.",
        "- Push the smallest recovery patch and confirm a later successful workflow closes this issue.",
    ),
}

SIGNATURE_HINT_RE = re.compile(
    r"(error|failed|failure|exception|traceback|panic|fatal|denied|"
    r"sqlstate|schema_migrations|duplicate key|notion|supabase|deno|flutter)",
    re.IGNORECASE,
)
DEFAULT_ANTHROPIC_MODEL = "claude-haiku-4-5-20251001"
ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages"


def append_summary(summary_path: str | None, title: str, lines: list[str]) -> None:
    if not summary_path:
        return
    path = Path(summary_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"\n## {title}\n\n")
        for line in lines:
            fh.write(f"{line}\n")


def latest_migrations(migrations_dir: Path, limit: int) -> list[Path]:
    if not migrations_dir.exists():
        return []
    files = [
        p for p in migrations_dir.iterdir()
        if p.is_file() and MIGRATION_FILE_RE.match(p.name)
    ]
    return sorted(files, key=lambda p: p.name, reverse=True)[:limit]


def local_migration_versions(migrations_dir: Path) -> set[str]:
    if not migrations_dir.exists():
        return set()
    return {
        match.group(1)
        for path in migrations_dir.iterdir()
        if path.is_file() and (match := MIGRATION_FILE_RE.match(path.name))
    }


def read_log_text(path: Path) -> str:
    data = path.read_bytes()
    sample = data[:2000]
    if b"\x00" in sample:
        return data.decode("utf-16", errors="replace")
    return data.decode("utf-8-sig", errors="replace")


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def compact_line(line: str, max_chars: int = 180) -> str:
    cleaned = strip_ansi(line)
    cleaned = TIMESTAMP_PREFIX_RE.sub("", cleaned).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    if len(cleaned) <= max_chars:
        return cleaned
    return cleaned[: max_chars - 1].rstrip() + "..."


def classify_workflow_failure(workflow_name: str, failed_step: str, log_text: str) -> str:
    haystack = "\n".join([workflow_name or "", failed_step or "", log_text or ""]).lower()
    for category, patterns in WORKFLOW_CATEGORY_PATTERNS:
        if any(pattern in haystack for pattern in patterns):
            return category
    return "generic-ci"


def workflow_recovery_draft(
    category: str,
    workflow_name: str,
    failed_step: str,
    error_signature: str,
) -> list[str]:
    heading = (
        f"- Category `{category or 'generic-ci'}` was detected for "
        f"`{workflow_name or 'unknown-workflow'}` / `{failed_step or 'unknown-step'}`."
    )
    signature = f"- Start from this error signature: `{error_signature or 'unknown'}`."
    return [heading, signature, *RECOVERY_DRAFTS.get(category, RECOVERY_DRAFTS["generic-ci"])]


def extract_error_signature(log_text: str, fallback: str = "unknown-step", max_chars: int = 180) -> str:
    candidates: list[str] = []
    for raw in (log_text or "").splitlines():
        line = compact_line(raw, max_chars=max_chars)
        if not line or NOISE_LINE_RE.search(line):
            continue
        if SIGNATURE_HINT_RE.search(line):
            candidates.append(line)
    if candidates:
        return candidates[-1]

    tail = [
        compact_line(line, max_chars=max_chars)
        for line in (log_text or "").splitlines()[-20:]
        if compact_line(line, max_chars=max_chars)
    ]
    if tail:
        return tail[-1]
    return compact_line(fallback or "unknown-step", max_chars=max_chars)


def recovery_scope_key(workflow_name: str, branch: str) -> str:
    payload = "|".join([workflow_name or "unknown-workflow", branch or "unknown-branch"])
    return "wfrs-" + hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def workflow_root_cause(
    workflow_name: str,
    branch: str,
    failed_step: str,
    log_text: str,
) -> dict[str, str]:
    category = classify_workflow_failure(workflow_name, failed_step, log_text)
    signature = extract_error_signature(log_text, fallback=failed_step or category)
    key_payload = "|".join(
        [
            workflow_name or "unknown-workflow",
            branch or "unknown-branch",
            failed_step or "unknown-step",
            category,
            signature,
        ]
    )
    return {
        "workflow_name": workflow_name or "unknown-workflow",
        "head_branch": branch or "unknown-branch",
        "failed_step": failed_step or "unknown-step",
        "failure_category": category,
        "error_signature": signature,
        "recovery_draft": "\n".join(
            workflow_recovery_draft(
                category=category,
                workflow_name=workflow_name,
                failed_step=failed_step,
                error_signature=signature,
            )
        ),
        "root_cause_key": "wfrc-" + hashlib.sha256(key_payload.encode("utf-8")).hexdigest()[:16],
        "recovery_scope_key": recovery_scope_key(workflow_name, branch),
    }


def parse_issue_markers(body: str | None) -> dict[str, str]:
    markers: dict[str, str] = {}
    for match in MARKER_RE.finditer(body or ""):
        markers[match.group(1)] = match.group(2).strip()
    return markers


def parse_iso_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def workflow_failure_metrics(issues: list[dict[str, object]]) -> dict[str, object]:
    tracked_count = len(issues)
    open_count = 0
    closed_count = 0
    recovered_durations: list[float] = []
    categories: dict[str, int] = {}

    for issue in issues:
        state = str(issue.get("state") or "").lower()
        if state == "closed":
            closed_count += 1
        else:
            open_count += 1

        markers = parse_issue_markers(str(issue.get("body") or ""))
        category = markers.get("failure_category", "unclassified")
        categories[category] = categories.get(category, 0) + 1

        created_at = parse_iso_datetime(str(issue.get("createdAt") or ""))
        closed_at = parse_iso_datetime(str(issue.get("closedAt") or ""))
        if state == "closed" and created_at and closed_at and closed_at >= created_at:
            recovered_durations.append((closed_at - created_at).total_seconds() / 3600)

    avg_recovery_hours: float | None = None
    if recovered_durations:
        avg_recovery_hours = round(sum(recovered_durations) / len(recovered_durations), 2)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tracked_count": tracked_count,
        "open_count": open_count,
        "closed_count": closed_count,
        "recovered_count": len(recovered_durations),
        "avg_recovery_hours": avg_recovery_hours,
        "categories": dict(sorted(categories.items())),
    }


def render_workflow_failure_metrics_markdown(metrics: dict[str, object]) -> list[str]:
    avg = metrics.get("avg_recovery_hours")
    avg_text = "n/a" if avg is None else f"{avg}h"
    categories = metrics.get("categories")
    if isinstance(categories, dict) and categories:
        category_text = ", ".join(f"`{name}`={count}" for name, count in categories.items())
    else:
        category_text = "none"
    return [
        "## Workflow failure hygiene",
        f"- Open workflow-failure issues: `{metrics.get('open_count', 0)}`",
        f"- Tracked workflow-failure issues: `{metrics.get('tracked_count', 0)}`",
        f"- Average recovery time: `{avg_text}` "
        f"({metrics.get('recovered_count', 0)} closed issues with timing)",
        f"- Root-cause categories: {category_text}",
    ]


def write_json_file(path: str | None, payload: dict[str, object]) -> None:
    if not path:
        return
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def truncate_middle(text: str, max_chars: int = 12000) -> str:
    if len(text) <= max_chars:
        return text
    keep = max_chars // 2
    omitted = len(text) - keep * 2
    return (
        text[:keep]
        + f"\n\n[... omitted {omitted} chars from the middle of the CI log ...]\n\n"
        + text[-keep:]
    )


def build_failure_summary_prompt(root: dict[str, str], log_text: str) -> str:
    return "\n".join(
        [
            "Summarize this GitHub Actions failure in a concise StackTrace-style report.",
            "Return Markdown with exactly these headings:",
            "1. What failed",
            "2. Where it failed",
            "3. Likely cause",
            "4. Next recovery step",
            "",
            "Keep it factual. Do not invent files, commands, or secrets.",
            "",
            "Known metadata:",
            f"- workflow: {root.get('workflow_name', 'unknown')}",
            f"- branch: {root.get('head_branch', 'unknown')}",
            f"- failed step: {root.get('failed_step', 'unknown')}",
            f"- category: {root.get('failure_category', 'unknown')}",
            f"- normalized signature: {root.get('error_signature', 'unknown')}",
            "",
            "Log excerpt:",
            "```text",
            truncate_middle(log_text),
            "```",
        ]
    )


def deterministic_failure_summary(root: dict[str, str], log_text: str) -> str:
    digest = log_digest(log_text, root.get("failure_category", "generic"), 12)
    evidence = "\n".join(f"- `{compact_line(line, max_chars=140)}`" for line in digest[-5:])
    if not evidence:
        evidence = "- No matching error lines were found; inspect the failed job log."
    return "\n".join(
        [
            "### What failed",
            f"`{root.get('workflow_name', 'unknown-workflow')}` failed in `{root.get('failed_step', 'unknown-step')}`.",
            "",
            "### Where it failed",
            f"Branch `{root.get('head_branch', 'unknown-branch')}` / category `{root.get('failure_category', 'generic-ci')}`.",
            "",
            "### Likely cause",
            f"The normalized signature is `{root.get('error_signature', 'unknown')}`.",
            "",
            "### Next recovery step",
            root.get("recovery_draft", "Inspect the failed job log and rerun the workflow after a focused fix."),
            "",
            "### Evidence",
            evidence,
        ]
    )


def extract_anthropic_text(payload: dict[str, object]) -> str:
    parts: list[str] = []
    for item in payload.get("content", []):  # type: ignore[union-attr]
        if isinstance(item, dict) and item.get("type") == "text":
            text = item.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts).strip()


def anthropic_failure_summary(prompt: str, *, api_key: str, model: str, timeout_seconds: int) -> str:
    body = json.dumps(
        {
            "model": model,
            "max_tokens": 700,
            "temperature": 0,
            "messages": [{"role": "user", "content": prompt}],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        ANTHROPIC_MESSAGES_URL,
        data=body,
        method="POST",
        headers={
            "content-type": "application/json",
            "anthropic-version": "2023-06-01",
            "x-api-key": api_key,
        },
    )
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        payload = json.loads(response.read().decode("utf-8"))
    text = extract_anthropic_text(payload)
    if not text:
        raise ValueError("Anthropic response did not contain text content")
    return text


def workflow_ai_summary(
    root: dict[str, str],
    log_text: str,
    *,
    timeout_seconds: int = 30,
) -> dict[str, object]:
    prompt = build_failure_summary_prompt(root, log_text)
    provider = "deterministic"
    model = ""
    error = ""
    summary = deterministic_failure_summary(root, log_text)

    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if anthropic_key:
        model = os.environ.get("ANTHROPIC_MODEL", DEFAULT_ANTHROPIC_MODEL).strip() or DEFAULT_ANTHROPIC_MODEL
        try:
            summary = anthropic_failure_summary(
                prompt,
                api_key=anthropic_key,
                model=model,
                timeout_seconds=timeout_seconds,
            )
            provider = "anthropic"
        except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
            error = str(exc)

    return {
        "provider": provider,
        "model": model,
        "fallback_used": provider == "deterministic",
        "error": error,
        "summary": summary,
    }


def workflow_ai_summary_cli(args: argparse.Namespace) -> int:
    log_path = Path(args.log)
    log_text = read_log_text(log_path) if log_path.exists() else ""
    root_path = Path(args.root_json)
    root = json.loads(root_path.read_text(encoding="utf-8")) if root_path.exists() else workflow_root_cause(
        workflow_name=args.workflow_name,
        branch=args.branch,
        failed_step=args.failed_step,
        log_text=log_text,
    )
    result = workflow_ai_summary(root, log_text, timeout_seconds=args.timeout_seconds)
    markdown = [
        f"<!-- ai_summary_provider: {result['provider']} -->",
        f"<!-- ai_summary_fallback_used: {str(result['fallback_used']).lower()} -->",
        str(result["summary"]).strip(),
    ]
    if result.get("error"):
        markdown.extend(["", f"_LLM summary fallback reason: `{result['error']}`_"])
    if args.markdown:
        output = Path(args.markdown)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("\n".join(markdown).strip() + "\n", encoding="utf-8")
    write_json_file(args.json, result)
    print("\n".join(markdown).strip())
    return 0


def log_digest(log_text: str, kind: str, max_lines: int) -> list[str]:
    keywords = DEN0_KEYWORDS if kind == "deno-lint" else DEPLOY_KEYWORDS
    matched: list[str] = []
    for raw in log_text.splitlines():
        line = raw.rstrip()
        if any(k in line.lower() for k in keywords):
            matched.append(line)
    if not matched:
        matched = [line.rstrip() for line in log_text.splitlines()[-max_lines:]]
    return matched[-max_lines:]


def classify_migration_failure(log_text: str) -> tuple[str, list[str]]:
    lower = log_text.lower()
    recommended_statuses: set[str] = set()
    recommended_versions: set[str] = set()
    for line in log_text.splitlines():
        if "supabase migration repair" not in line.lower():
            continue
        status_match = re.search(r"--status\s+(applied|reverted)\b", line, re.IGNORECASE)
        versions = VERSION_RE.findall(line)
        if status_match and versions:
            recommended_statuses.add(status_match.group(1).lower())
            recommended_versions.update(versions)
    if len(recommended_statuses) == 1 and recommended_versions:
        return recommended_statuses.pop(), sorted(recommended_versions)
    if len(recommended_statuses) > 1:
        return "unknown", []

    if "schema_migrations_pkey" in lower and "duplicate key" in lower:
        lines = log_text.splitlines()
        duplicate_versions: set[str] = set()
        for index, line in enumerate(lines):
            match = re.search(
                r"key\s*\(\s*version\s*\)\s*=\s*\(\s*(\d{14})\s*\)",
                line,
                re.IGNORECASE,
            )
            if not match:
                continue
            diagnostic_block = "\n".join(
                lines[max(0, index - 3) : min(len(lines), index + 4)]
            ).lower()
            if (
                "schema_migrations_pkey" in diagnostic_block
                and "duplicate key" in diagnostic_block
            ):
                duplicate_versions.add(match.group(1))
        return "applied", sorted(duplicate_versions)
    if "remote migration" in lower or "migration versions not found" in lower:
        lines = log_text.splitlines()
        marker = next(
            (
                index
                for index, line in enumerate(lines)
                if "remote migration" in line.lower()
                or "migration versions not found" in line.lower()
            ),
            None,
        )
        if marker is not None:
            remote_versions: set[str] = set()
            table_started = False
            for line in lines[marker + 1 : marker + 30]:
                match = re.match(r"^\s*\|?\s*(\d{14})\s*(?:\|.*)?$", line)
                if match:
                    table_started = True
                    remote_versions.add(match.group(1))
                    continue
                if table_started:
                    break
                if not line.strip() or re.match(r"^\s*[|+:-]+\s*$", line):
                    continue
                break
            return "reverted", sorted(remote_versions)
    return "unknown", []


def run_command(command: list[str], log_path: Path) -> int:
    proc = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    output = proc.stdout or ""
    print(output, end="")
    with log_path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"\n$ {' '.join(command)}\n")
        fh.write(output)
        fh.write(f"\nexit={proc.returncode}\n")
    return proc.returncode


def summarize_log(args: argparse.Namespace) -> int:
    log_path = Path(args.log)
    if not log_path.exists():
        print(f"log file not found: {log_path}", file=sys.stderr)
        return 2
    text = read_log_text(log_path)
    digest = log_digest(text, args.kind, args.max_lines)
    lines = [
        f"- Log: `{log_path}`",
        f"- Extracted lines: {len(digest)}",
        "",
        "```text",
        *digest,
        "```",
    ]
    append_summary(args.summary, f"{args.kind} failure digest", lines)
    print("\n".join(lines))
    return 0


def workflow_root_cause_cli(args: argparse.Namespace) -> int:
    log_text = ""
    log_path = Path(args.log) if args.log else None
    if log_path and log_path.exists():
        log_text = read_log_text(log_path)
    result = workflow_root_cause(
        workflow_name=args.workflow_name,
        branch=args.branch,
        failed_step=args.failed_step,
        log_text=log_text,
    )
    write_json_file(args.json, result)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def workflow_scope_cli(args: argparse.Namespace) -> int:
    result = {
        "workflow_name": args.workflow_name or "unknown-workflow",
        "head_branch": args.branch or "unknown-branch",
        "recovery_scope_key": recovery_scope_key(args.workflow_name, args.branch),
    }
    write_json_file(args.json, result)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def workflow_failure_metrics_cli(args: argparse.Namespace) -> int:
    issues_path = Path(args.issues_json)
    issues = json.loads(issues_path.read_text(encoding="utf-8"))
    if not isinstance(issues, list):
        print("issues JSON must be a list", file=sys.stderr)
        return 2
    metrics = workflow_failure_metrics(issues)
    write_json_file(args.json, metrics)
    markdown = render_workflow_failure_metrics_markdown(metrics)
    if args.markdown:
        markdown_path = Path(args.markdown)
        markdown_path.parent.mkdir(parents=True, exist_ok=True)
        markdown_path.write_text("\n".join(markdown) + "\n", encoding="utf-8")
    print("\n".join(markdown))
    return 0


def supabase_db_push(args: argparse.Namespace) -> int:
    log_dir = Path(args.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    push_log = log_dir / "supabase-db-push.log"
    migration_list_log = log_dir / "supabase-migration-list.log"
    preflight_log = log_dir / "supabase-migration-preflight.log"

    # Each invocation must classify only its own command output. Reusing a log
    # directory must never replay an earlier repair recommendation or error.
    push_log.write_text("", encoding="utf-8")
    migration_list_log.write_text("", encoding="utf-8")

    migrations_dir = Path(args.migrations_dir)
    recent = latest_migrations(migrations_dir, args.recent_limit)
    timestamp = datetime.now(timezone.utc).isoformat()
    summary_lines = [
        f"- Checked at: `{timestamp}`",
        f"- Recent local migration files: {len(recent)}",
    ]
    if recent:
        summary_lines.append("")
        summary_lines.append("```text")
        summary_lines.extend(p.name for p in recent)
        summary_lines.append("```")
    append_summary(args.summary, "Supabase migration preflight", summary_lines)

    with preflight_log.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(f"checked_at={timestamp}\n")
        fh.write("recent_migrations:\n")
        for migration in recent:
            fh.write(f"- {migration.name}\n")

    run_command(["supabase", "migration", "list"], migration_list_log)

    push_args = ["supabase", "db", "push"]
    if args.include_all:
        push_args.append("--include-all")
    first_exit = run_command(push_args, push_log)
    if first_exit == 0:
        append_summary(args.summary, "Supabase migration result", ["- `supabase db push` succeeded on the first attempt."])
        return 0

    log_text = read_log_text(push_log)
    repair_status, versions = classify_migration_failure(log_text)
    digest = log_digest(log_text, "supabase", args.max_digest_lines)
    failure_lines = [
        f"- First attempt exit: `{first_exit}`",
        f"- Repair classification: `{repair_status}`",
        f"- Extracted versions: `{', '.join(versions) if versions else 'none'}`",
        "",
        "```text",
        *digest,
        "```",
    ]
    append_summary(args.summary, "Supabase migration failure digest", failure_lines)

    if repair_status == "unknown" or not versions:
        print("No safe migration repair action detected; leaving failure intact.")
        return first_exit

    local_versions = local_migration_versions(migrations_dir)
    invalid_versions = (
        [version for version in versions if version not in local_versions]
        if repair_status == "applied"
        else [version for version in versions if version in local_versions]
    )
    if invalid_versions:
        append_summary(
            args.summary,
            "Supabase migration repair rejected",
            [
                f"- Repair status: `{repair_status}`",
                f"- Unsafe versions: `{', '.join(invalid_versions)}`",
                "- Result: no migration history changes were attempted.",
            ],
        )
        print(
            "Migration repair direction did not match the local migration set; "
            "leaving failure intact."
        )
        return first_exit

    for version in versions:
        repair_exit = run_command(
            ["supabase", "migration", "repair", "--status", repair_status, version],
            push_log,
        )
        if repair_exit != 0:
            append_summary(
                args.summary,
                "Supabase migration repair failed",
                [
                    f"- Repair status: `{repair_status}`",
                    f"- Failed version: `{version}`",
                    f"- Repair exit: `{repair_exit}`",
                    "- Result: database push was not retried.",
                ],
            )
            return repair_exit

    retry_exit = run_command(push_args, push_log)
    result = "succeeded" if retry_exit == 0 else "failed"
    append_summary(
        args.summary,
        "Supabase migration repair retry",
        [
            f"- Repair status used: `{repair_status}`",
            f"- Versions: `{', '.join(versions)}`",
            f"- Retry result: `{result}`",
        ],
    )
    return retry_exit


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract CI/deploy failure digests")
    sub = parser.add_subparsers(dest="command", required=True)

    summarize = sub.add_parser("summarize-log")
    summarize.add_argument("log")
    summarize.add_argument("--kind", default="generic")
    summarize.add_argument("--summary")
    summarize.add_argument("--max-lines", type=int, default=80)
    summarize.set_defaults(func=summarize_log)

    root_cause = sub.add_parser("workflow-root-cause")
    root_cause.add_argument("--workflow-name", required=True)
    root_cause.add_argument("--branch", required=True)
    root_cause.add_argument("--failed-step", required=True)
    root_cause.add_argument("--log")
    root_cause.add_argument("--json")
    root_cause.set_defaults(func=workflow_root_cause_cli)

    ai_summary = sub.add_parser("workflow-ai-summary")
    ai_summary.add_argument("--workflow-name", required=True)
    ai_summary.add_argument("--branch", required=True)
    ai_summary.add_argument("--failed-step", required=True)
    ai_summary.add_argument("--log", required=True)
    ai_summary.add_argument("--root-json", required=True)
    ai_summary.add_argument("--markdown")
    ai_summary.add_argument("--json")
    ai_summary.add_argument("--timeout-seconds", type=int, default=30)
    ai_summary.set_defaults(func=workflow_ai_summary_cli)

    scope = sub.add_parser("workflow-scope")
    scope.add_argument("--workflow-name", required=True)
    scope.add_argument("--branch", required=True)
    scope.add_argument("--json")
    scope.set_defaults(func=workflow_scope_cli)

    metrics = sub.add_parser("workflow-failure-metrics")
    metrics.add_argument("--issues-json", required=True)
    metrics.add_argument("--markdown")
    metrics.add_argument("--json")
    metrics.set_defaults(func=workflow_failure_metrics_cli)

    supabase = sub.add_parser("supabase-db-push")
    supabase.add_argument("--log-dir", default=".deploy-logs")
    supabase.add_argument("--summary")
    supabase.add_argument("--migrations-dir", default="supabase/migrations")
    supabase.add_argument("--recent-limit", type=int, default=10)
    supabase.add_argument("--max-digest-lines", type=int, default=80)
    supabase.add_argument("--include-all", action="store_true")
    supabase.set_defaults(func=supabase_db_push)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
