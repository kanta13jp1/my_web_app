#!/usr/bin/env python3
"""Local worktree ownership registry and preflight guard.

The registry is intentionally local-only by default. It records which instance
is actively working on which issue and path set, then runs a small preflight
before a new worktree starts editing. It complements instance_conflict_predictor
by catching planned ownership overlaps before files are staged.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_REGISTRY = REPO_ROOT / ".cache" / "worktree-registry.json"
RISK_ORDER = {"Low": 0, "Medium": 1, "High": 2}
ACTIVE_STATUSES = {"active", "planned", "in_progress"}


@dataclass
class RegistryEntry:
    instance: str
    owner: str
    issue: str
    worktree: str
    branch: str
    paths: list[str]
    status: str
    updated_at: str
    notes: str = ""


@dataclass
class PreflightEvent:
    level: str
    kind: str
    subject: str
    reason: str
    action: str
    related: list[str]


def run_text(command: list[str], cwd: Path = REPO_ROOT, check: bool = False) -> str:
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
    return result.stdout.strip()


def git_text(args: list[str], cwd: Path = REPO_ROOT) -> str:
    return run_text(["git", *args], cwd=cwd)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def normalize_path(path: str | Path, base: Path = REPO_ROOT) -> str:
    raw = Path(path)
    try:
        if raw.is_absolute():
            return raw.resolve().relative_to(base.resolve()).as_posix()
    except (OSError, ValueError):
        return raw.as_posix().replace("\\", "/").strip("/")
    return raw.as_posix().replace("\\", "/").strip("/")


def normalize_paths(paths: Iterable[str | Path]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in paths:
        normalized = normalize_path(item)
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(normalized)
    return result


def paths_overlap(left: str, right: str) -> bool:
    a = normalize_path(left)
    b = normalize_path(right)
    if not a or not b:
        return False
    return a == b or a.startswith(f"{b}/") or b.startswith(f"{a}/")


def overlap_set(left: Iterable[str], right: Iterable[str]) -> list[str]:
    overlaps: list[str] = []
    for a in left:
        for b in right:
            if paths_overlap(a, b):
                overlaps.append(a if len(a) >= len(b) else b)
    return normalize_paths(overlaps)


def load_registry(path: Path) -> list[RegistryEntry]:
    if not path.exists():
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return []
    entries = payload.get("entries", []) if isinstance(payload, dict) else []
    result: list[RegistryEntry] = []
    for item in entries:
        if not isinstance(item, dict):
            continue
        result.append(
            RegistryEntry(
                instance=str(item.get("instance", "unknown")),
                owner=str(item.get("owner", "")),
                issue=str(item.get("issue", "")),
                worktree=str(item.get("worktree", "")),
                branch=str(item.get("branch", "")),
                paths=normalize_paths(str(path) for path in item.get("paths", [])),
                status=str(item.get("status", "active")),
                updated_at=str(item.get("updated_at", "")),
                notes=str(item.get("notes", "")),
            )
        )
    return result


def save_registry(path: Path, entries: list[RegistryEntry]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": 1,
        "updated_at": now_iso(),
        "entries": [asdict(entry) for entry in entries],
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def entry_key(entry: RegistryEntry) -> tuple[str, str, str]:
    return (entry.instance.lower(), entry.issue, str(Path(entry.worktree).resolve()).lower())


def upsert_entry(entries: list[RegistryEntry], entry: RegistryEntry) -> list[RegistryEntry]:
    key = entry_key(entry)
    kept = [existing for existing in entries if entry_key(existing) != key]
    kept.append(entry)
    return sorted(kept, key=lambda item: (item.instance, item.issue, item.worktree))


def current_branch(cwd: Path = REPO_ROOT) -> str:
    branch = git_text(["branch", "--show-current"], cwd=cwd)
    return branch or git_text(["rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd) or "detached"


def upstream_name(cwd: Path = REPO_ROOT) -> str:
    return git_text(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd=cwd)


def ahead_behind(cwd: Path = REPO_ROOT) -> tuple[int | None, int | None]:
    upstream = upstream_name(cwd)
    if not upstream:
        return None, None
    raw = git_text(["rev-list", "--left-right", "--count", f"HEAD...{upstream}"], cwd=cwd)
    parts = raw.split()
    if len(parts) != 2:
        return None, None
    return int(parts[0]), int(parts[1])


def changed_files_from(base_ref: str) -> list[str]:
    raw = git_text(["diff", "--name-only", f"{base_ref}...HEAD"])
    return normalize_paths(raw.splitlines())


def staged_files() -> list[str]:
    raw = git_text(["diff", "--cached", "--name-only"])
    return normalize_paths(raw.splitlines())


def dirty_paths(cwd: Path) -> list[str]:
    raw = git_text(["status", "--short"], cwd=cwd)
    paths: list[str] = []
    for line in raw.splitlines():
        if len(line) < 4:
            continue
        value = line[3:].strip()
        if " -> " in value:
            value = value.split(" -> ", 1)[1]
        paths.append(value)
    return normalize_paths(paths)


def worktree_entries() -> list[dict[str, str]]:
    raw = git_text(["worktree", "list", "--porcelain"])
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


def open_pr_exists(branch: str) -> bool:
    if not branch or branch == "detached":
        return False
    raw = run_text(["gh", "pr", "view", branch, "--json", "number"])
    return bool(raw.strip())


def detect_registry_conflicts(
    entries: list[RegistryEntry],
    target_paths: list[str],
    instance: str,
    issue: str,
) -> list[PreflightEvent]:
    events: list[PreflightEvent] = []
    if not target_paths:
        return events
    for entry in entries:
        if entry.status not in ACTIVE_STATUSES:
            continue
        if entry.instance.lower() == instance.lower() and entry.issue == issue:
            continue
        overlaps = overlap_set(target_paths, entry.paths)
        if not overlaps:
            continue
        events.append(
            PreflightEvent(
                level="High",
                kind="registry-path-overlap",
                subject=", ".join(overlaps[:8]),
                reason=(
                    f"{entry.instance} issue {entry.issue or 'unknown'} already reserved "
                    "one or more target paths."
                ),
                action="Pause, split the scope, or update the handoff before editing these paths.",
                related=[entry.worktree, entry.branch],
            )
        )
    return events


def detect_dirty_overlaps(target_paths: list[str], current_root: Path) -> list[PreflightEvent]:
    events: list[PreflightEvent] = []
    entries = worktree_entries()
    if not entries:
        return events

    primary = Path(entries[0].get("worktree", ""))
    primary_dirty = dirty_paths(primary) if primary.exists() else []
    if primary_dirty:
        overlaps = overlap_set(target_paths, primary_dirty)
        if overlaps:
            events.append(
                PreflightEvent(
                    level="High",
                    kind="primary-dirty-overlap",
                    subject=", ".join(overlaps[:8]),
                    reason="The primary worktree has uncommitted user changes in target paths.",
                    action="Do not overwrite root changes; coordinate or choose a narrower path set.",
                    related=[str(primary)],
                )
            )
        else:
            events.append(
                PreflightEvent(
                    level="Medium",
                    kind="primary-dirty",
                    subject=str(primary),
                    reason=f"The primary worktree has {len(primary_dirty)} dirty path(s).",
                    action="Keep using an isolated fresh worktree and avoid touching those dirty files.",
                    related=primary_dirty[:12],
                )
            )

    for entry in entries[1:]:
        worktree = entry.get("worktree")
        if not worktree:
            continue
        path = Path(worktree)
        try:
            if path.resolve() == current_root.resolve() or not path.exists():
                continue
        except OSError:
            continue
        dirty = dirty_paths(path)
        overlaps = overlap_set(target_paths, dirty)
        if overlaps:
            branch = entry.get("branch", "unknown").replace("refs/heads/", "")
            events.append(
                PreflightEvent(
                    level="High",
                    kind="dirty-worktree-overlap",
                    subject=", ".join(overlaps[:8]),
                    reason=f"Dirty worktree {branch} already has local edits in target paths.",
                    action="Coordinate before editing; local changes are not visible in GitHub PR checks.",
                    related=[str(path)],
                )
            )
    return events


def detect_branch_state(branch: str) -> list[PreflightEvent]:
    events: list[PreflightEvent] = []
    ahead, behind = ahead_behind()
    if ahead is None or behind is None:
        events.append(
            PreflightEvent(
                level="Medium",
                kind="branch-upstream-missing",
                subject=branch,
                reason="Current branch has no comparable upstream.",
                action="Push with upstream tracking before long-running work, then rerun preflight.",
                related=[],
            )
        )
        return events
    if behind:
        events.append(
            PreflightEvent(
                level="Medium",
                kind="branch-behind",
                subject=branch,
                reason=f"Current branch is behind upstream by {behind} commit(s).",
                action="Run `git fetch origin main` and rebase before continuing.",
                related=[],
            )
        )
    if ahead and not open_pr_exists(branch):
        events.append(
            PreflightEvent(
                level="Medium",
                kind="unpushed-pr-candidate",
                subject=branch,
                reason=f"Current branch is ahead by {ahead} commit(s) and has no detected PR.",
                action="Open a scoped PR or push/sync the branch before starting another task.",
                related=[],
            )
        )
    return events


def event_level(events: Iterable[PreflightEvent]) -> str:
    risk = "Low"
    for event in events:
        if RISK_ORDER[event.level] > RISK_ORDER[risk]:
            risk = event.level
    return risk


def fail_code(risk: str, fail_on: str) -> int:
    if fail_on == "never":
        return 0
    threshold = "High" if fail_on == "high" else "Medium"
    return 1 if RISK_ORDER[risk] >= RISK_ORDER[threshold] else 0


def build_target_paths(args: argparse.Namespace) -> list[str]:
    paths: list[str] = []
    paths.extend(args.paths or [])
    if args.staged:
        paths.extend(staged_files())
    if args.changed_from:
        paths.extend(changed_files_from(args.changed_from))
    return normalize_paths(paths)


def render_markdown(
    entries: list[RegistryEntry],
    live_worktrees: list[dict[str, str]],
    events: list[PreflightEvent],
    risk: str,
    target_paths: list[str],
) -> str:
    lines = [
        "# Worktree Registry Preflight",
        "",
        f"- overall risk: **{risk}**",
        f"- registered active entries: {sum(1 for item in entries if item.status in ACTIVE_STATUSES)}",
        f"- live worktrees: {len(live_worktrees)}",
        "",
        "## Target Paths",
        "",
    ]
    lines.extend(f"- `{path}`" for path in target_paths[:80]) if target_paths else lines.append("- none")

    lines.extend(["", "## Registry", "", "| instance | issue | status | branch | paths |", "|---|---|---|---|---|"])
    for entry in entries[:80]:
        lines.append(
            f"| {entry.instance} | {entry.issue or '-'} | {entry.status} | "
            f"`{entry.branch}` | {', '.join(f'`{path}`' for path in entry.paths[:6]) or '-'} |"
        )

    lines.extend(["", "## Live Worktrees", "", "| branch | worktree |", "|---|---|"])
    for item in live_worktrees[:80]:
        branch = item.get("branch", item.get("detached", "detached")).replace("refs/heads/", "")
        lines.append(f"| `{branch or 'detached'}` | `{item.get('worktree', '')}` |")

    lines.extend(["", "## Events", ""])
    if events:
        for event in events[:80]:
            related = ", ".join(item for item in event.related if item)
            lines.append(f"- **{event.level}** `{event.kind}`: {event.subject}")
            lines.append(f"  - reason: {event.reason}")
            lines.append(f"  - action: {event.action}")
            if related:
                lines.append(f"  - related: {related}")
    else:
        lines.append("- No ownership conflict detected.")
    return "\n".join(lines)


def write_outputs(
    args: argparse.Namespace,
    entries: list[RegistryEntry],
    live_worktrees: list[dict[str, str]],
    events: list[PreflightEvent],
    risk: str,
    target_paths: list[str],
) -> None:
    payload = {
        "timestamp": now_iso(),
        "risk": risk,
        "target_paths": target_paths,
        "entries": [asdict(entry) for entry in entries],
        "live_worktrees": live_worktrees,
        "events": [asdict(event) for event in events],
    }
    if args.json_out:
        path = REPO_ROOT / args.json_out
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path}")
    if args.output:
        path = REPO_ROOT / args.output
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_markdown(entries, live_worktrees, events, risk, target_paths), encoding="utf-8")
        print(f"wrote {path}")


def register_command(args: argparse.Namespace) -> int:
    registry = REPO_ROOT / args.registry
    worktree = str(Path(args.worktree).resolve()) if args.worktree else str(REPO_ROOT.resolve())
    branch = args.branch or current_branch()
    entry = RegistryEntry(
        instance=args.instance,
        owner=args.owner or args.instance,
        issue=args.issue or "",
        worktree=worktree,
        branch=branch,
        paths=normalize_paths(args.paths),
        status=args.status,
        updated_at=now_iso(),
        notes=args.notes or "",
    )
    entries = upsert_entry(load_registry(registry), entry)
    save_registry(registry, entries)
    print(f"registered {entry.instance} issue {entry.issue or '-'} in {registry}")
    return 0


def list_command(args: argparse.Namespace) -> int:
    entries = load_registry(REPO_ROOT / args.registry)
    live = worktree_entries()
    if args.json:
        print(
            json.dumps(
                {"entries": [asdict(entry) for entry in entries], "live_worktrees": live},
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        print(render_markdown(entries, live, [], "Low", []))
    return 0


def preflight_command(args: argparse.Namespace) -> int:
    registry = REPO_ROOT / args.registry
    entries = load_registry(registry)
    target_paths = build_target_paths(args)
    branch = current_branch()
    current_root = Path(git_text(["rev-parse", "--show-toplevel"]) or REPO_ROOT)

    events: list[PreflightEvent] = []
    events.extend(detect_registry_conflicts(entries, target_paths, args.instance, args.issue or ""))
    events.extend(detect_dirty_overlaps(target_paths, current_root))
    events.extend(detect_branch_state(branch))

    risk = event_level(events)
    write_outputs(args, entries, worktree_entries(), events, risk, target_paths)
    print(f"risk: {risk}")
    for event in events[:12]:
        print(f"{event.level}: {event.kind}: {event.subject}")
    return fail_code(risk, args.fail_on)


def release_command(args: argparse.Namespace) -> int:
    registry = REPO_ROOT / args.registry
    entries = load_registry(registry)
    changed = False
    for entry in entries:
        if entry.instance.lower() == args.instance.lower() and (
            not args.issue or entry.issue == args.issue
        ):
            entry.status = "released"
            entry.updated_at = now_iso()
            changed = True
    if changed:
        save_registry(registry, entries)
    print("released" if changed else "no matching entry")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", default=str(DEFAULT_REGISTRY.relative_to(REPO_ROOT)))
    sub = parser.add_subparsers(dest="command", required=True)

    register = sub.add_parser("register")
    register.add_argument("--instance", required=True)
    register.add_argument("--owner", default="")
    register.add_argument("--issue", default="")
    register.add_argument("--worktree", default="")
    register.add_argument("--branch", default="")
    register.add_argument("--paths", nargs="+", required=True)
    register.add_argument("--status", default="active")
    register.add_argument("--notes", default="")
    register.set_defaults(func=register_command)

    list_parser = sub.add_parser("list")
    list_parser.add_argument("--json", action="store_true")
    list_parser.set_defaults(func=list_command)

    preflight = sub.add_parser("preflight")
    preflight.add_argument("--instance", required=True)
    preflight.add_argument("--issue", default="")
    preflight.add_argument("--paths", nargs="*", default=[])
    preflight.add_argument("--staged", action="store_true")
    preflight.add_argument("--changed-from", default="")
    preflight.add_argument("--output", default="")
    preflight.add_argument("--json-out", default="")
    preflight.add_argument("--fail-on", choices=["never", "medium", "high"], default="never")
    preflight.set_defaults(func=preflight_command)

    release = sub.add_parser("release")
    release.add_argument("--instance", required=True)
    release.add_argument("--issue", default="")
    release.set_defaults(func=release_command)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
