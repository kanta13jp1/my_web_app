#!/usr/bin/env python3
"""Predict cross-instance conflicts for the 12-agent development fleet.

This script is intentionally dependency-free so it can run from Claude Code
hooks, Codex sessions, GitHub Actions, and local PowerShell terminals.

It supports three operating modes:
- session start / handoff: scan recent commits, open PRs, and dirty worktrees.
- pre-add / pre-commit: pass staged or explicit files and warn on overlap.
- migration planning: check a migration timestamp and suggest the next free one.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request
from collections import defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parent.parent
MIGRATION_RE = re.compile(r"^(?P<ts>\d{14})_(?P<name>.+)\.sql$")

RISK_ORDER = {"Low": 0, "Medium": 1, "High": 2}

INSTANCE_PATTERNS: list[tuple[str, list[re.Pattern[str]]]] = [
    ("vscode", [re.compile(r"\bvscode\b", re.IGNORECASE)]),
    ("win", [re.compile(r"\bwin\b", re.IGNORECASE)]),
    ("ps1", [re.compile(r"\bps#?1\b", re.IGNORECASE)]),
    ("ps2", [re.compile(r"\bps#?2\b", re.IGNORECASE)]),
    ("ps3", [re.compile(r"\bps#?3\b", re.IGNORECASE)]),
    ("ps4", [re.compile(r"\bps#?4\b", re.IGNORECASE)]),
    ("ps5", [re.compile(r"\bps#?5\b", re.IGNORECASE)]),
    ("ps6", [re.compile(r"\bps#?6\b", re.IGNORECASE)]),
    (
        "codex1",
        [
            re.compile(r"\bcodex\s*#?1\b", re.IGNORECASE),
            re.compile(r"\bcodex/codex1[/-]", re.IGNORECASE),
            re.compile(r"\bcodex1[-_]", re.IGNORECASE),
        ],
    ),
    (
        "codex2",
        [
            re.compile(r"\bcodex\s*#?2\b", re.IGNORECASE),
            re.compile(r"\bcodex/codex2[/-]", re.IGNORECASE),
            re.compile(r"\bcodex2[-_]", re.IGNORECASE),
        ],
    ),
    ("claude", [re.compile(r"\bclaude\b", re.IGNORECASE)]),
]


@dataclass
class RiskEvent:
    level: str
    kind: str
    subject: str
    reason: str
    action: str
    related: list[str]


def run_text(command: list[str], cwd: Path = REPO_ROOT, check: bool = True) -> str:
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            check=check,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        if check:
            raise
        return ""
    return result.stdout


def git_text(args: list[str], cwd: Path = REPO_ROOT, check: bool = True) -> str:
    return run_text(["git", *args], cwd=cwd, check=check)


def classify_text(text: str) -> str:
    for instance, patterns in INSTANCE_PATTERNS:
        if any(pattern.search(text) for pattern in patterns):
            return instance
    return "unknown"


def rel_path(path: str | Path, base: Path = REPO_ROOT) -> str:
    raw = Path(path)
    try:
        if raw.is_absolute():
            return raw.resolve().relative_to(base.resolve()).as_posix()
    except ValueError:
        return raw.as_posix().replace("\\", "/")
    return raw.as_posix().replace("\\", "/")


def unique(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        normalized = value.strip().replace("\\", "/")
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(normalized)
    return result


def current_branch() -> str:
    branch = git_text(["rev-parse", "--abbrev-ref", "HEAD"], check=False).strip()
    return branch or "unknown"


def changed_files_from(base_ref: str) -> list[str]:
    files = git_text(["diff", "--name-only", f"{base_ref}...HEAD"], check=False)
    return unique(files.splitlines())


def staged_files() -> list[str]:
    files = git_text(["diff", "--cached", "--name-only"], check=False)
    return unique(files.splitlines())


def recent_commits(hours: int) -> list[dict[str, object]]:
    since = (datetime.now(timezone.utc) - timedelta(hours=hours)).strftime(
        "%Y-%m-%d %H:%M:%S"
    )
    fmt = "%H%x09%aI%x09%an%x09%s"
    raw = git_text(
        ["log", f"--since={since}", f"--pretty=format:{fmt}", "--name-only", "--no-merges"],
        check=False,
    )
    commits: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) >= 4:
            if current:
                commits.append(current)
            sha, authored_at, author, subject = parts[0], parts[1], parts[2], "\t".join(parts[3:])
            instance = classify_text(f"{subject} {author}")
            current = {
                "sha": sha,
                "authored_at": authored_at,
                "author": author,
                "subject": subject,
                "instance": instance,
                "files": [],
            }
            continue
        if current and line.strip():
            files = current["files"]
            assert isinstance(files, list)
            files.append(line.strip().replace("\\", "/"))
    if current:
        commits.append(current)
    return commits


def worktree_entries() -> list[dict[str, str]]:
    raw = git_text(["worktree", "list", "--porcelain"], check=False)
    entries: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in raw.splitlines():
        if not line.strip():
            if current:
                entries.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        current[key] = value
    if current:
        entries.append(current)
    return entries


def dirty_worktree_files(limit: int) -> list[dict[str, object]]:
    current_root = REPO_ROOT.resolve()
    dirty: list[dict[str, object]] = []
    for entry in worktree_entries()[:limit]:
        worktree = entry.get("worktree")
        if not worktree:
            continue
        path = Path(worktree)
        try:
            if path.resolve() == current_root:
                continue
        except OSError:
            continue
        raw = git_text(["status", "--short"], cwd=path, check=False)
        files: list[str] = []
        for line in raw.splitlines():
            if len(line) < 4:
                continue
            status_path = line[3:].strip()
            if " -> " in status_path:
                status_path = status_path.split(" -> ", 1)[1]
            files.append(status_path.replace("\\", "/"))
        if files:
            branch = entry.get("branch", "unknown").replace("refs/heads/", "")
            dirty.append(
                {
                    "worktree": worktree,
                    "branch": branch,
                    "instance": classify_text(f"{branch} {worktree}"),
                    "files": unique(files),
                }
            )
    return dirty


def open_prs_with_files(limit: int) -> list[dict[str, object]]:
    raw = run_text(
        [
            "gh",
            "pr",
            "list",
            "--state",
            "open",
            "--limit",
            str(limit),
            "--json",
            "number,title,headRefName,author,url,isDraft",
        ],
        check=False,
    )
    if not raw.strip():
        return []
    try:
        prs = json.loads(raw)
    except json.JSONDecodeError:
        return []

    enriched: list[dict[str, object]] = []
    for pr in prs:
        number = str(pr.get("number", ""))
        files_raw = run_text(
            ["gh", "pr", "view", number, "--json", "files"],
            check=False,
        )
        files: list[str] = []
        if files_raw.strip():
            try:
                parsed = json.loads(files_raw)
                files = [
                    str(item.get("path", "")).replace("\\", "/")
                    for item in parsed.get("files", [])
                    if item.get("path")
                ]
            except json.JSONDecodeError:
                files = []
        branch = str(pr.get("headRefName") or "")
        title = str(pr.get("title") or "")
        enriched.append(
            {
                "number": pr.get("number"),
                "title": title,
                "headRefName": branch,
                "url": pr.get("url"),
                "isDraft": bool(pr.get("isDraft")),
                "instance": classify_text(f"{branch} {title}"),
                "files": unique(files),
            }
        )
    return enriched


def migration_files() -> dict[str, list[str]]:
    migrations = REPO_ROOT / "supabase" / "migrations"
    by_timestamp: dict[str, list[str]] = defaultdict(list)
    if not migrations.exists():
        return {}
    for path in migrations.glob("*.sql"):
        match = MIGRATION_RE.match(path.name)
        if match:
            by_timestamp[match.group("ts")].append(rel_path(path))
    return dict(by_timestamp)


def extract_migration_timestamp(path: str) -> str | None:
    name = Path(path.replace("\\", "/")).name
    match = MIGRATION_RE.match(name)
    return match.group("ts") if match else None


def suggest_timestamp(base_timestamp: str | None, used: set[str]) -> str:
    if base_timestamp and re.fullmatch(r"\d{14}", base_timestamp):
        cursor = datetime.strptime(base_timestamp, "%Y%m%d%H%M%S")
    else:
        cursor = datetime.now().replace(microsecond=0)
    for _ in range(24 * 60):
        candidate = cursor.strftime("%Y%m%d%H%M%S")
        if candidate not in used:
            return candidate
        cursor += timedelta(minutes=1)
    return (cursor + timedelta(days=1)).strftime("%Y%m%d%H%M%S")


def event_level(events: Iterable[RiskEvent]) -> str:
    risk = "Low"
    for event in events:
        if RISK_ORDER[event.level] > RISK_ORDER[risk]:
            risk = event.level
    return risk


def detect_recent_file_overlaps(commits: list[dict[str, object]]) -> list[RiskEvent]:
    file_to_instances: dict[str, set[str]] = defaultdict(set)
    file_to_shas: dict[str, set[str]] = defaultdict(set)
    for commit in commits:
        instance = str(commit.get("instance", "unknown"))
        if instance == "unknown":
            continue
        for file_path in commit.get("files", []):
            file_to_instances[str(file_path)].add(instance)
            file_to_shas[str(file_path)].add(str(commit.get("sha", ""))[:8])

    events: list[RiskEvent] = []
    for file_path, instances in sorted(file_to_instances.items()):
        if len(instances) < 2:
            continue
        events.append(
            RiskEvent(
                level="Medium",
                kind="recent-file-overlap",
                subject=file_path,
                reason=f"Edited by multiple instances in the scan window: {', '.join(sorted(instances))}.",
                action="Rebase before editing this file; coordinate ownership in the handoff channel.",
                related=sorted(file_to_shas[file_path]),
            )
        )
    return events


def detect_target_overlaps(
    target_files: list[str],
    commits: list[dict[str, object]],
    prs: list[dict[str, object]],
    dirty_worktrees: list[dict[str, object]],
) -> list[RiskEvent]:
    if not target_files:
        return []
    targets = set(target_files)
    events: list[RiskEvent] = []

    recent_by_file: dict[str, list[str]] = defaultdict(list)
    for commit in commits:
        instance = str(commit.get("instance", "unknown"))
        if instance == "unknown":
            continue
        label = f"{instance}:{str(commit.get('sha', ''))[:8]}"
        for file_path in commit.get("files", []):
            recent_by_file[str(file_path)].append(label)

    for target in sorted(targets):
        if target in recent_by_file:
            events.append(
                RiskEvent(
                    level="Medium",
                    kind="target-recent-overlap",
                    subject=target,
                    reason="The target file was touched recently by another identified instance.",
                    action="Check the related commits before staging; prefer a narrow rebase or handoff comment.",
                    related=sorted(set(recent_by_file[target])),
                )
            )

    for pr in prs:
        overlap = sorted(targets.intersection(set(pr.get("files", []))))
        if not overlap:
            continue
        events.append(
            RiskEvent(
                level="Medium",
                kind="target-open-pr-overlap",
                subject=", ".join(overlap[:5]),
                reason=f"Open PR #{pr.get('number')} touches the same file(s).",
                action="Review the PR or coordinate ownership before pushing a competing branch.",
                related=[str(pr.get("url", ""))],
            )
        )

    for entry in dirty_worktrees:
        overlap = sorted(targets.intersection(set(entry.get("files", []))))
        if not overlap:
            continue
        events.append(
            RiskEvent(
                level="High",
                kind="target-dirty-worktree-overlap",
                subject=", ".join(overlap[:5]),
                reason=f"Dirty worktree {entry.get('branch')} already has local edits to the same file(s).",
                action="Pause and coordinate before git add; this is an active local conflict risk.",
                related=[str(entry.get("worktree", ""))],
            )
        )
    return events


def detect_migration_risks(
    target_files: list[str],
    commits: list[dict[str, object]],
    requested_timestamp: str | None,
) -> tuple[list[RiskEvent], dict[str, object]]:
    used = migration_files()
    used_set = set(used)
    timestamps = [ts for ts in (extract_migration_timestamp(path) for path in target_files) if ts]
    if requested_timestamp:
        timestamps.append(requested_timestamp)
    timestamps = unique(timestamps)

    events: list[RiskEvent] = []
    suggestions: dict[str, str] = {}
    for ts in timestamps:
        existing = used.get(ts, [])
        if existing:
            suggestions[ts] = suggest_timestamp(ts, used_set)
            events.append(
                RiskEvent(
                    level="High",
                    kind="migration-timestamp-collision",
                    subject=ts,
                    reason=f"Migration timestamp already exists in {len(existing)} file(s).",
                    action=f"Use next free timestamp {suggestions[ts]} or rerun check_migration_timestamps.py.",
                    related=existing[:10],
                )
            )
        else:
            suggestions[ts] = ts

    should_scan_clusters = not target_files or bool(timestamps) or requested_timestamp is not None
    if should_scan_clusters:
        migration_pushes: list[tuple[datetime, str, str]] = []
        for commit in commits:
            files = [str(path) for path in commit.get("files", [])]
            if not any(path.startswith("supabase/migrations/") and path.endswith(".sql") for path in files):
                continue
            instance = str(commit.get("instance", "unknown"))
            if instance == "unknown":
                continue
            try:
                authored = datetime.fromisoformat(str(commit.get("authored_at")))
            except ValueError:
                continue
            migration_pushes.append((authored, instance, str(commit.get("sha", ""))[:8]))

        migration_pushes.sort(key=lambda item: item[0])
        for index, (left_time, left_instance, left_sha) in enumerate(migration_pushes):
            for right_time, right_instance, right_sha in migration_pushes[index + 1 :]:
                delta = int((right_time - left_time).total_seconds())
                if delta > 3600:
                    break
                if left_instance == right_instance:
                    continue
                events.append(
                    RiskEvent(
                        level="High",
                        kind="migration-cluster",
                        subject=f"{left_instance}/{right_instance}",
                        reason=f"Different instances pushed migrations within {delta}s.",
                        action="Run migration timestamp checks against latest origin/main before pushing.",
                        related=[left_sha, right_sha],
                    )
                )

    if not timestamps and requested_timestamp is None and not target_files:
        suggestions["next_free"] = suggest_timestamp(None, used_set)

    return events, {
        "requested_timestamps": timestamps,
        "suggestions": suggestions,
        "used_count": len(used_set),
    }


def render_markdown(
    now: datetime,
    hours: int,
    target_files: list[str],
    risk: str,
    events: list[RiskEvent],
    migration: dict[str, object],
    notify: list[str],
) -> str:
    lines: list[str] = [
        f"# Instance Conflict Predictor - {now.strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        f"- window: last {hours} hours",
        f"- branch: `{current_branch()}`",
        f"- overall risk: **{risk}**",
        f"- notification routes: {', '.join(notify) if notify else 'none'}",
        "",
        "## Target Files",
        "",
    ]
    if target_files:
        lines.extend(f"- `{path}`" for path in target_files[:80])
    else:
        lines.append("- No explicit target files. Session-wide scan only.")

    lines.extend(["", "## Risk Events", ""])
    if events:
        for event in events[:80]:
            related = ", ".join(item for item in event.related if item)
            lines.append(f"- **{event.level}** `{event.kind}`: {event.subject}")
            lines.append(f"  - reason: {event.reason}")
            lines.append(f"  - action: {event.action}")
            if related:
                lines.append(f"  - related: {related}")
    else:
        lines.append("- No conflict risk detected.")

    lines.extend(["", "## Migration Timestamp Guidance", ""])
    suggestions = migration.get("suggestions", {})
    if isinstance(suggestions, dict) and suggestions:
        for source, suggestion in suggestions.items():
            lines.append(f"- `{source}` -> `{suggestion}`")
    else:
        lines.append("- No migration timestamp guidance generated.")

    lines.extend(
        [
            "",
            "## Recommended Use",
            "",
            "- Session start: `python scripts/instance_conflict_predictor.py --changed-from origin/main`",
            "- Pre-add: `python scripts/instance_conflict_predictor.py --staged --fail-on high`",
            "- Migration: `python scripts/instance_conflict_predictor.py --migration-timestamp YYYYMMDDHHMMSS`",
            "",
            "*Generated by `scripts/instance_conflict_predictor.py`.*",
        ]
    )
    return "\n".join(lines)


def parse_notify(raw: str) -> list[str]:
    if not raw or raw == "none":
        return []
    return [item.strip().lower() for item in raw.split(",") if item.strip()]


def notify_routes(routes: list[str], risk: str, events: list[RiskEvent], report_path: Path) -> list[str]:
    delivered: list[str] = []
    if not routes:
        return delivered

    summary = {
        "risk": risk,
        "event_count": len(events),
        "report": str(report_path),
        "top_events": [asdict(event) for event in events[:5]],
    }

    if "console" in routes:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        delivered.append("console")

    if "slack" in routes:
        webhook = os.environ.get("CONFLICT_PREDICTOR_SLACK_WEBHOOK") or os.environ.get("SLACK_WEBHOOK_URL")
        if webhook:
            payload = json.dumps(
                {
                    "text": (
                        f"Instance conflict predictor: {risk} risk, "
                        f"{len(events)} event(s). Report: {report_path}"
                    )
                }
            ).encode("utf-8")
            request = urllib.request.Request(
                webhook,
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            try:
                with urllib.request.urlopen(request, timeout=10) as response:
                    if 200 <= response.status < 300:
                        delivered.append("slack")
            except OSError:
                pass

    for route in ("notion", "wbs"):
        if route in routes:
            # Notion/WBS writes are intentionally not performed here because
            # those integrations require project-specific credentials and row
            # schemas. The JSON output is the stable handoff surface.
            delivered.append(f"{route}:json-ready")

    return delivered


def fail_code(risk: str, fail_on: str) -> int:
    if fail_on == "never":
        return 0
    threshold = "High" if fail_on == "high" else "Medium"
    return 1 if RISK_ORDER[risk] >= RISK_ORDER[threshold] else 0


def build_target_files(args: argparse.Namespace) -> list[str]:
    files: list[str] = []
    files.extend(args.files or [])
    if args.staged:
        files.extend(staged_files())
    if args.changed_from:
        files.extend(changed_files_from(args.changed_from))
    return unique(rel_path(path) for path in files)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--files", nargs="*", default=[])
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--changed-from", default="")
    parser.add_argument("--migration-timestamp", default="")
    parser.add_argument("--open-pr-limit", type=int, default=30)
    parser.add_argument("--worktree-limit", type=int, default=40)
    parser.add_argument("--output", default="")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--notify", default="none", help="Comma-separated: none,console,slack,notion,wbs")
    parser.add_argument("--fail-on", choices=["never", "medium", "high"], default="never")
    args = parser.parse_args()

    now = datetime.now(timezone.utc)
    target_files = build_target_files(args)
    commits = recent_commits(args.hours)
    prs = open_prs_with_files(args.open_pr_limit)
    dirty = dirty_worktree_files(args.worktree_limit)

    events: list[RiskEvent] = []
    events.extend(detect_recent_file_overlaps(commits))
    events.extend(detect_target_overlaps(target_files, commits, prs, dirty))
    migration_events, migration_guidance = detect_migration_risks(
        target_files,
        commits,
        args.migration_timestamp or None,
    )
    events.extend(migration_events)

    risk = event_level(events)
    routes = parse_notify(args.notify)

    output_path = (
        REPO_ROOT / args.output
        if args.output
        else REPO_ROOT / "docs" / "instance-conflict" / f"{now.strftime('%Y-%m-%d')}.md"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        render_markdown(now, args.hours, target_files, risk, events, migration_guidance, routes),
        encoding="utf-8",
    )

    json_payload = {
        "timestamp": now.isoformat(),
        "hours": args.hours,
        "branch": current_branch(),
        "target_files": target_files,
        "risk": risk,
        "events": [asdict(event) for event in events],
        "migration": migration_guidance,
        "open_prs_scanned": len(prs),
        "dirty_worktrees_scanned": len(dirty),
        "report": str(output_path),
    }
    if args.json_out:
        json_path = REPO_ROOT / args.json_out
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(json_payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"wrote {json_path}")

    delivered = notify_routes(routes, risk, events, output_path)
    if delivered:
        json_payload["notifications"] = delivered

    print(f"wrote {output_path}")
    print(f"risk: {risk}")
    if migration_guidance.get("suggestions"):
        print("migration suggestions:")
        for source, suggestion in migration_guidance["suggestions"].items():
            print(f"  {source} -> {suggestion}")

    return fail_code(risk, args.fail_on)


if __name__ == "__main__":
    sys.exit(main())
