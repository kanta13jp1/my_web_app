#!/usr/bin/env python3
"""Store a secret-free MUSUBI release checkpoint inside the worktree git-dir."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
from typing import Any


SENSITIVE_VALUE = re.compile(
    r"(?:eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|"
    r"(?:password|secret|service[_ -]?role|jwt|token)\s*[:=]\s*\S+)",
    re.IGNORECASE,
)


def locate_git_dir(start: Path | None = None) -> Path:
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        marker = candidate / ".git"
        if marker.is_dir():
            return marker.resolve()
        if marker.is_file():
            line = marker.read_text(encoding="utf-8").strip()
            if line.lower().startswith("gitdir:"):
                raw_path = Path(line.split(":", 1)[1].strip())
                return (raw_path if raw_path.is_absolute() else candidate / raw_path).resolve()
    raise RuntimeError("Git管理ディレクトリが見つかりません")


def repository_identity(git_dir: Path) -> tuple[str, str]:
    head_text = (git_dir / "HEAD").read_text(encoding="utf-8").strip()
    if not head_text.startswith("ref: "):
        return "detached", head_text[:12] or "unknown"

    reference = head_text[5:]
    branch = reference.removeprefix("refs/heads/")
    common_dir = git_dir
    common_marker = git_dir / "commondir"
    if common_marker.exists():
        raw_common = Path(common_marker.read_text(encoding="utf-8").strip())
        common_dir = (raw_common if raw_common.is_absolute() else git_dir / raw_common).resolve()

    loose_reference = common_dir / reference
    if loose_reference.exists():
        return branch, loose_reference.read_text(encoding="utf-8").strip()[:12]

    packed_refs = common_dir / "packed-refs"
    if packed_refs.exists():
        for line in packed_refs.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.endswith(f" {reference}"):
                return branch, line.split(" ", 1)[0][:12]
    return branch, "unknown"


def state_path() -> Path:
    return locate_git_dir() / "codex" / "musubi-social-release-state.json"


def read_state(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_secret_free(values: list[str]) -> None:
    for value in values:
        if SENSITIVE_VALUE.search(value):
            raise ValueError("secretまたはJWTらしい値はcheckpointへ保存できません")


def command_show(path: Path) -> int:
    state = read_state(path)
    if state is None:
        print("NO_CHECKPOINT")
        return 0
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0


def command_set(path: Path, args: argparse.Namespace) -> int:
    text_values = [args.phase, args.status, args.summary, args.next_action, *args.evidence, *args.blocker]
    ensure_secret_free(text_values)
    path.parent.mkdir(parents=True, exist_ok=True)
    branch, head = repository_identity(path.parents[1])
    state = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "branch": branch,
        "head": head,
        "phase": args.phase,
        "status": args.status,
        "summary": args.summary,
        "evidence": args.evidence,
        "blockers": args.blocker,
        "next_action": args.next_action,
    }
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)
    print(f"CHECKPOINT_SAVED={path}")
    return 0


def command_clear(path: Path) -> int:
    if path.exists():
        path.unlink()
        print(f"CHECKPOINT_REMOVED={path}")
    else:
        print("NO_CHECKPOINT")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("show")
    set_parser = subparsers.add_parser("set")
    set_parser.add_argument("--phase", required=True)
    set_parser.add_argument("--status", choices=("pending", "in_progress", "passed", "blocked"), required=True)
    set_parser.add_argument("--summary", required=True)
    set_parser.add_argument("--evidence", action="append", default=[])
    set_parser.add_argument("--blocker", action="append", default=[])
    set_parser.add_argument("--next-action", required=True)
    subparsers.add_parser("clear")
    args = parser.parse_args()

    try:
        path = state_path()
        if args.command == "show":
            return command_show(path)
        if args.command == "set":
            return command_set(path, args)
        return command_clear(path)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
