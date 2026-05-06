#!/usr/bin/env python3
"""Safely prune developer caches for Issue #1984 axis C.

The default mode is a dry-run report. Use --apply to run cache maintenance
commands or delete age-gated NotebookLM cache files. The script is intentionally
dependency-free so it can run from local Windows app sessions, scheduled tasks,
or GitHub Actions.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


NOTEBOOKLM_CACHE_LEAVES = (
    "Cache",
    "Code Cache",
    "GPUCache",
    "Logs",
    "cache",
    "logs",
    "temp",
    "tmp",
)
NOTEBOOKLM_APP_NAMES = (
    "NotebookLM",
    "notebooklm",
    "notebook-lm",
    "notebooklm-desktop",
)
PROTECTED_NOTEBOOKLM_NAMES = {
    ".env",
    "auth.json",
    "cookies.json",
    "local_state.json",
    "login.json",
    "session.json",
    "state.json",
    "storage_state.json",
    "tokens.json",
}


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass
class CleanupAction:
    name: str
    kind: str
    target: str
    status: str
    reason: str
    command: list[str] = field(default_factory=list)
    before_mb: float | None = None
    after_mb: float | None = None
    reclaimed_mb: float | None = None
    returncode: int | None = None
    stdout_tail: str = ""
    stderr_tail: str = ""


def run_command(args: list[str], cwd: Path | None = None, timeout: int = 300) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except PermissionError as exc:
        return CommandResult(126, "", str(exc))
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.strip() if isinstance(exc.stdout, str) else ""
        return CommandResult(124, stdout, f"timed out after {timeout}s")
    return CommandResult(proc.returncode, proc.stdout.strip(), proc.stderr.strip())


def run_git(args: list[str], cwd: Path, timeout: int = 60) -> CommandResult:
    return run_command(["git", *args], cwd=cwd, timeout=timeout)


def git_text(args: list[str], cwd: Path, default: str = "") -> str:
    result = run_git(args, cwd)
    if result.code != 0:
        return default
    return result.stdout.strip()


def git_root(cwd: Path) -> Path:
    root = git_text(["rev-parse", "--show-toplevel"], cwd)
    if not root:
        raise RuntimeError(f"not inside a git worktree: {cwd}")
    return Path(root).resolve(strict=False)


def parse_worktree_paths(raw: str) -> list[Path]:
    paths: list[Path] = []
    for line in raw.splitlines():
        if line.startswith("worktree "):
            paths.append(Path(line.split(" ", 1)[1]).resolve(strict=False))
    return paths


def worktree_paths(root: Path) -> list[Path]:
    raw = git_text(["worktree", "list", "--porcelain"], root)
    paths = parse_worktree_paths(raw)
    return paths or [root]


def dedupe_paths(paths: list[Path]) -> list[Path]:
    seen: set[str] = set()
    unique: list[Path] = []
    for path in paths:
        key = norm_path(path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


def norm_path(path: Path) -> str:
    return os.path.normcase(str(path.resolve(strict=False)))


def same_or_child(child: Path, parent: Path) -> bool:
    child_s = norm_path(child)
    parent_s = norm_path(parent)
    return child_s == parent_s or child_s.startswith(parent_s + os.sep)


def directory_size_bytes(path: Path) -> int:
    if not path.exists():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0

    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return total


def bytes_to_mb(value: int) -> float:
    return round(value / (1024 * 1024), 1)


def sum_existing_paths(paths: list[Path]) -> float:
    return bytes_to_mb(sum(directory_size_bytes(path) for path in paths if path.exists()))


def tail_text(text: str, limit: int = 500) -> str:
    if len(text) <= limit:
        return text
    return text[-limit:]


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


def command_action(
    *,
    name: str,
    target: str,
    command: list[str],
    cwd: Path,
    apply: bool,
    before_paths: list[Path] | None = None,
    timeout: int = 300,
) -> CleanupAction:
    before = sum_existing_paths(before_paths or [])
    if not apply:
        return CleanupAction(
            name=name,
            kind="command",
            target=target,
            status="planned",
            reason="dry-run; pass --apply to execute",
            command=command,
            before_mb=before,
        )

    result = run_command(command, cwd=cwd, timeout=timeout)
    after = sum_existing_paths(before_paths or [])
    status = "success" if result.code == 0 else "failed"
    reason = "command completed" if result.code == 0 else "command failed"
    return CleanupAction(
        name=name,
        kind="command",
        target=target,
        status=status,
        reason=reason,
        command=command,
        before_mb=before,
        after_mb=after,
        reclaimed_mb=max(0.0, round(before - after, 1)),
        returncode=result.code,
        stdout_tail=tail_text(result.stdout),
        stderr_tail=tail_text(result.stderr),
    )


def skip_action(name: str, kind: str, target: str, reason: str) -> CleanupAction:
    return CleanupAction(name=name, kind=kind, target=target, status="skipped", reason=reason)


def flutter_targets(root: Path, include_worktrees: bool) -> list[Path]:
    paths = worktree_paths(root) if include_worktrees else [root]
    return [path for path in dedupe_paths(paths) if (path / "pubspec.yaml").exists()]


def git_is_dirty(path: Path) -> bool:
    result = run_git(["-C", str(path), "status", "--porcelain"], path)
    if result.code != 0:
        return True
    return bool(result.stdout.strip())


def collect_flutter_actions(args: argparse.Namespace, root: Path) -> list[CleanupAction]:
    targets = flutter_targets(root, include_worktrees=args.include_worktrees)
    if not targets:
        return [skip_action("flutter clean", "command", str(root), "no pubspec.yaml worktrees found")]
    if not command_available("flutter"):
        return [
            skip_action("flutter clean", "command", str(path), "flutter executable not found")
            for path in targets
        ]

    actions: list[CleanupAction] = []
    for path in targets:
        if git_is_dirty(path) and not args.allow_dirty_worktrees:
            actions.append(
                skip_action(
                    "flutter clean",
                    "command",
                    str(path),
                    "dirty worktree skipped; pass --allow-dirty-worktrees to override",
                )
            )
            continue
        before_paths = [path / "build", path / ".dart_tool"]
        actions.append(
            command_action(
                name="flutter clean",
                target=str(path),
                command=["flutter", "clean"],
                cwd=path,
                apply=args.apply,
                before_paths=before_paths,
                timeout=args.command_timeout,
            )
        )
    return actions


def npm_cache_paths(root: Path) -> list[Path]:
    if not command_available("npm"):
        return []
    result = run_command(["npm", "config", "get", "cache"], cwd=root, timeout=30)
    if result.code != 0 or not result.stdout.strip():
        return []
    return [Path(result.stdout.strip()).expanduser().resolve(strict=False)]


def pnpm_store_paths(root: Path) -> list[Path]:
    if not command_available("pnpm"):
        return []
    result = run_command(["pnpm", "store", "path"], cwd=root, timeout=30)
    if result.code != 0 or not result.stdout.strip():
        return []
    return [Path(result.stdout.strip()).expanduser().resolve(strict=False)]


def pip_cache_paths(root: Path) -> list[Path]:
    result = run_command([sys.executable, "-m", "pip", "cache", "dir"], cwd=root, timeout=30)
    if result.code != 0 or not result.stdout.strip():
        return []
    return [Path(result.stdout.strip()).expanduser().resolve(strict=False)]


def pub_cache_paths() -> list[Path]:
    paths: list[Path] = []
    explicit = os.environ.get("PUB_CACHE")
    if explicit:
        paths.append(Path(explicit).expanduser())
    local_appdata = os.environ.get("LOCALAPPDATA")
    appdata = os.environ.get("APPDATA")
    if local_appdata:
        paths.append(Path(local_appdata) / "Pub" / "Cache")
    if appdata:
        paths.append(Path(appdata) / "Pub" / "Cache")
    paths.append(Path.home() / ".pub-cache")
    return dedupe_paths([path.resolve(strict=False) for path in paths])


def collect_tool_cache_actions(args: argparse.Namespace, root: Path) -> list[CleanupAction]:
    actions: list[CleanupAction] = []

    if command_available("npm"):
        actions.append(
            command_action(
                name="npm cache verify",
                target="npm cache",
                command=["npm", "cache", "verify"],
                cwd=root,
                apply=args.apply,
                before_paths=npm_cache_paths(root),
                timeout=args.command_timeout,
            )
        )
    else:
        actions.append(skip_action("npm cache verify", "command", "npm cache", "npm executable not found"))

    if command_available("pnpm"):
        actions.append(
            command_action(
                name="pnpm store prune",
                target="pnpm store",
                command=["pnpm", "store", "prune"],
                cwd=root,
                apply=args.apply,
                before_paths=pnpm_store_paths(root),
                timeout=args.command_timeout,
            )
        )
    else:
        actions.append(skip_action("pnpm store prune", "command", "pnpm store", "pnpm executable not found"))

    if command_available("dart"):
        actions.append(
            command_action(
                name="dart pub cache clean",
                target="pub cache",
                command=["dart", "pub", "cache", "clean", "--force"],
                cwd=root,
                apply=args.apply,
                before_paths=pub_cache_paths(),
                timeout=args.command_timeout,
            )
        )
    elif command_available("flutter"):
        actions.append(
            command_action(
                name="flutter pub cache clean",
                target="pub cache",
                command=["flutter", "pub", "cache", "clean", "--force"],
                cwd=root,
                apply=args.apply,
                before_paths=pub_cache_paths(),
                timeout=args.command_timeout,
            )
        )
    else:
        actions.append(skip_action("dart pub cache clean", "command", "pub cache", "dart/flutter executable not found"))

    pip_version = run_command([sys.executable, "-m", "pip", "--version"], cwd=root, timeout=30)
    if pip_version.code == 0:
        actions.append(
            command_action(
                name="pip cache purge",
                target="pip cache",
                command=[sys.executable, "-m", "pip", "cache", "purge"],
                cwd=root,
                apply=args.apply,
                before_paths=pip_cache_paths(root),
                timeout=args.command_timeout,
            )
        )
    else:
        actions.append(skip_action("pip cache purge", "command", "pip cache", "python -m pip unavailable"))

    return actions


def notebooklm_cache_roots() -> list[Path]:
    direct_cache_roots: list[Path] = []
    for env_name in ("NOTEBOOKLM_CACHE_DIR", "NOTEBOOKLM_CACHE_ROOT"):
        value = os.environ.get(env_name)
        if value:
            direct_cache_roots.append(Path(value).expanduser())

    home = Path.home()
    direct_cache_roots.append(home / ".cache" / "notebooklm")

    container_bases: list[Path] = [home / ".notebooklm"]
    for env_name in ("LOCALAPPDATA", "APPDATA"):
        value = os.environ.get(env_name)
        if not value:
            continue
        parent = Path(value)
        for app_name in NOTEBOOKLM_APP_NAMES:
            container_bases.append(parent / app_name)

    candidates = list(direct_cache_roots)
    for base in container_bases:
        for leaf in NOTEBOOKLM_CACHE_LEAVES:
            candidates.append(base / leaf)
    return dedupe_paths([path.resolve(strict=False) for path in candidates])


def allowed_cleanup_roots(repo_root: Path) -> list[Path]:
    roots = [Path.home().resolve(strict=False), repo_root.resolve(strict=False)]
    for env_name in ("LOCALAPPDATA", "APPDATA", "TEMP", "TMP"):
        value = os.environ.get(env_name)
        if value:
            roots.append(Path(value).resolve(strict=False))
    return dedupe_paths(roots)


def is_safe_notebooklm_path(path: Path, repo_root: Path) -> bool:
    resolved = path.resolve(strict=False)
    if not any(same_or_child(resolved, root) for root in allowed_cleanup_roots(repo_root)):
        return False
    parts = {part.lower() for part in resolved.parts}
    return any("notebooklm" in part for part in parts) or any(
        name.lower() in parts for name in NOTEBOOKLM_APP_NAMES
    )


def stale_children(path: Path, max_age_days: int) -> list[Path]:
    if not path.exists() or not path.is_dir():
        return []
    cutoff = time.time() - max_age_days * 24 * 60 * 60
    stale: list[Path] = []
    try:
        children = list(path.iterdir())
    except OSError:
        return []
    for child in children:
        if child.name in PROTECTED_NOTEBOOKLM_NAMES:
            continue
        try:
            mtime = child.stat().st_mtime
        except OSError:
            continue
        if mtime <= cutoff:
            stale.append(child)
    return stale


def remove_child(path: Path) -> bool:
    try:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
        return True
    except OSError:
        return False


def notebooklm_cleanup_action(args: argparse.Namespace, repo_root: Path, path: Path) -> CleanupAction:
    if not path.exists():
        return skip_action("notebooklm cache prune", "filesystem", str(path), "path not found")
    if not path.is_dir():
        return skip_action("notebooklm cache prune", "filesystem", str(path), "path is not a directory")
    if not is_safe_notebooklm_path(path, repo_root):
        return skip_action("notebooklm cache prune", "filesystem", str(path), "outside known NotebookLM cache roots")

    children = stale_children(path, args.cache_age_days)
    before = sum_existing_paths(children)
    if not children:
        return CleanupAction(
            name="notebooklm cache prune",
            kind="filesystem",
            target=str(path),
            status="skipped",
            reason=f"no cache children older than {args.cache_age_days} days",
            before_mb=0.0,
        )
    if not args.apply:
        return CleanupAction(
            name="notebooklm cache prune",
            kind="filesystem",
            target=str(path),
            status="planned",
            reason=f"dry-run; {len(children)} child paths older than {args.cache_age_days} days",
            before_mb=before,
        )

    removed = 0
    for child in children:
        if remove_child(child):
            removed += 1
    after_children = [child for child in children if child.exists()]
    after = sum_existing_paths(after_children)
    status = "success" if removed == len(children) else "failed"
    reason = f"removed {removed}/{len(children)} child paths older than {args.cache_age_days} days"
    return CleanupAction(
        name="notebooklm cache prune",
        kind="filesystem",
        target=str(path),
        status=status,
        reason=reason,
        before_mb=before,
        after_mb=after,
        reclaimed_mb=max(0.0, round(before - after, 1)),
    )


def collect_notebooklm_actions(args: argparse.Namespace, repo_root: Path) -> list[CleanupAction]:
    actions = [
        notebooklm_cleanup_action(args, repo_root, path)
        for path in notebooklm_cache_roots()
        if path.exists()
    ]
    if actions:
        return actions
    return [skip_action("notebooklm cache prune", "filesystem", "notebooklm cache roots", "no NotebookLM cache roots found")]


def print_report(actions: list[CleanupAction], *, applied: bool) -> None:
    print("")
    print("=== Dev Cache Cleanup Report ===")
    print(f"mode: {'apply' if applied else 'dry-run'}")
    print("")
    headers = ("status", "name", "before_mb", "reclaimed_mb", "reason", "target")
    rows = [
        (
            action.status,
            action.name,
            f"{action.before_mb:.1f}" if action.before_mb is not None else "",
            f"{action.reclaimed_mb:.1f}" if action.reclaimed_mb is not None else "",
            action.reason,
            action.target,
        )
        for action in actions
    ]
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = min(max(widths[index], len(cell)), 64)

    def trim(value: str, width: int) -> str:
        if len(value) <= width:
            return value
        return value[: max(0, width - 3)] + "..."

    print("  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print(
            "  ".join(
                trim(cell, widths[index]).ljust(widths[index])
                for index, cell in enumerate(row)
            )
        )
    print("")
    totals = status_counts(actions)
    for status in ("planned", "success", "skipped", "failed"):
        print(f"{status}: {totals.get(status, 0)}")
    print(f"estimated reclaim: {estimated_reclaim_mb(actions):.1f} MB")
    print(f"actual reclaim:    {actual_reclaim_mb(actions):.1f} MB")


def status_counts(actions: list[CleanupAction]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for action in actions:
        counts[action.status] = counts.get(action.status, 0) + 1
    return counts


def estimated_reclaim_mb(actions: list[CleanupAction]) -> float:
    return round(
        sum(action.before_mb or 0.0 for action in actions if action.status in {"planned", "success"}),
        1,
    )


def actual_reclaim_mb(actions: list[CleanupAction]) -> float:
    return round(sum(action.reclaimed_mb or 0.0 for action in actions), 1)


def summary_payload(args: argparse.Namespace, root: Path, actions: list[CleanupAction]) -> dict[str, Any]:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "apply" if args.apply else "dry-run",
        "root": str(root),
        "include_worktrees": bool(args.include_worktrees),
        "cache_age_days": int(args.cache_age_days),
        "total": len(actions),
        "counts": status_counts(actions),
        "estimated_reclaim_mb": estimated_reclaim_mb(actions),
        "actual_reclaim_mb": actual_reclaim_mb(actions),
        "actions": [asdict(action) for action in actions],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository/worktree root.")
    parser.add_argument("--apply", action="store_true", help="Execute cleanup instead of dry-run reporting.")
    parser.add_argument(
        "--include-worktrees",
        action="store_true",
        help="Run flutter clean against every clean git worktree with pubspec.yaml.",
    )
    parser.add_argument(
        "--allow-dirty-worktrees",
        action="store_true",
        help="Allow flutter clean in dirty worktrees. Default is to skip them.",
    )
    parser.add_argument(
        "--cache-age-days",
        type=int,
        default=7,
        help="Minimum age for NotebookLM cache children selected for pruning.",
    )
    parser.add_argument("--command-timeout", type=int, default=300, help="Per-command timeout in seconds.")
    parser.add_argument("--json", action="store_true", help="Print the machine-readable summary.")
    parser.add_argument("--json-out", type=Path, help="Write the machine-readable summary.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = git_root(args.root)
    actions: list[CleanupAction] = []
    actions.extend(collect_flutter_actions(args, root))
    actions.extend(collect_tool_cache_actions(args, root))
    actions.extend(collect_notebooklm_actions(args, root))

    payload = summary_payload(args, root, actions)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_report(actions, applied=args.apply)

    return 1 if any(action.status == "failed" for action in actions) else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
