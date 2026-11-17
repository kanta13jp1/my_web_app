#!/usr/bin/env python3
"""Audit Git worktrees and persist secret-free backlog lane checkpoints."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


SENSITIVE_VALUE = re.compile(
    r"(?:Bearer\s+\S+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|"
    r"gh[pousr]_[A-Za-z0-9_]+|(?:sk|rk)_(?:live|test)_\S+|whsec_\S+|"
    r"(?:password|secret|service[_ -]?role|jwt|token)\s*[:=]\s*\S+)",
    re.IGNORECASE,
)
CHECKPOINT_STATUSES = (
    "planned",
    "in_progress",
    "paused",
    "blocked",
    "ready_to_push",
    "pushed",
    "ci_pending",
    "merge_ready",
    "merged",
    "cleaned",
)
OPERATION_MARKERS = (
    "index.lock",
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "rebase-merge",
    "rebase-apply",
    "sequencer",
)


class CommandError(RuntimeError):
    pass


def run(
    command: list[str],
    *,
    check: bool = True,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise CommandError(detail or f"Command failed: {' '.join(command)}")
    return proc


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["git", "-C", str(repo), *args], check=check)


def repository_root(repo: Path) -> Path:
    value = git(repo, "rev-parse", "--show-toplevel").stdout.strip()
    return Path(value).resolve()


def common_git_dir(repo: Path) -> Path:
    value = git(
        repo,
        "rev-parse",
        "--path-format=absolute",
        "--git-common-dir",
    ).stdout.strip()
    return Path(value).resolve()


def parse_worktrees(repo: Path) -> list[dict[str, Any]]:
    output = git(repo, "worktree", "list", "--porcelain").stdout
    records: list[dict[str, Any]] = []
    record: dict[str, Any] = {}
    for line in output.splitlines():
        if not line:
            if record:
                records.append(record)
                record = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            record["path"] = str(Path(value).resolve())
        elif key == "HEAD":
            record["head"] = value
        elif key == "branch":
            record["branch"] = value.removeprefix("refs/heads/")
        elif key in {"bare", "detached", "prunable"}:
            record[key] = True if not value else value
        elif key == "locked":
            record["locked"] = value or True
    if record:
        records.append(record)
    return records


def git_path(repo: Path, name: str) -> Path:
    value = git(
        repo,
        "rev-parse",
        "--path-format=absolute",
        "--git-path",
        name,
    ).stdout.strip()
    return Path(value).resolve()


def ref_exists(repo: Path, ref: str) -> bool:
    proc = git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}", check=False)
    return proc.returncode == 0


def is_ancestor(repo: Path, ancestor: str, descendant: str) -> bool:
    proc = git(repo, "merge-base", "--is-ancestor", ancestor, descendant, check=False)
    return proc.returncode == 0


def audit_one(
    record: dict[str, Any],
    *,
    primary: Path,
    base: str,
) -> dict[str, Any]:
    path = Path(record["path"]).resolve()
    result = dict(record)
    result["path"] = str(path)
    result["primary"] = path == primary
    result["exists"] = path.exists()
    if not path.exists():
        result.update(clean=False, dirty_paths=[], errors=["worktree path is missing"])
        return result

    errors: list[str] = []
    status = git(path, "status", "--porcelain=v1", "--untracked-files=normal", check=False)
    dirty_lines = [line for line in status.stdout.splitlines() if line]
    if status.returncode != 0:
        errors.append(status.stderr.strip() or "git status failed")
    result["clean"] = status.returncode == 0 and not dirty_lines
    result["dirty_paths"] = [line[3:] if len(line) > 3 else line for line in dirty_lines]

    branch_proc = git(path, "branch", "--show-current", check=False)
    branch = branch_proc.stdout.strip() or record.get("branch") or "detached"
    result["branch"] = branch
    head_proc = git(path, "rev-parse", "HEAD", check=False)
    head = head_proc.stdout.strip() if head_proc.returncode == 0 else record.get("head", "")
    result["head"] = head

    upstream_proc = git(
        path,
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
        check=False,
    )
    upstream = upstream_proc.stdout.strip() if upstream_proc.returncode == 0 else None
    result["upstream"] = upstream
    result["ahead"] = None
    result["behind"] = None
    result["upstream_matches_head"] = None
    if upstream:
        counts = git(path, "rev-list", "--left-right", "--count", f"{upstream}...HEAD", check=False)
        if counts.returncode == 0:
            left, right = counts.stdout.split()
            result["behind"] = int(left)
            result["ahead"] = int(right)
        upstream_head = git(path, "rev-parse", upstream, check=False)
        if upstream_head.returncode == 0:
            result["upstream_matches_head"] = upstream_head.stdout.strip() == head

    active_markers = [name for name in OPERATION_MARKERS if git_path(path, name).exists()]
    result["active_git_operations"] = active_markers
    result["base"] = base
    result["base_available"] = ref_exists(path, base)
    result["merged_into_base"] = (
        bool(head) and result["base_available"] and is_ancestor(path, head, base)
    )
    result["errors"] = errors
    return result


def audit(repo: Path, target: Path | None, base: str) -> dict[str, Any]:
    root = repository_root(repo)
    records = parse_worktrees(root)
    if not records:
        raise CommandError("No registered worktrees found")
    primary = Path(records[0]["path"]).resolve()
    if target is not None:
        resolved = target.resolve()
        records = [item for item in records if Path(item["path"]).resolve() == resolved]
        if not records:
            raise CommandError(f"Target is not a registered worktree: {resolved}")
    return {
        "schema_version": 1,
        "repository_root": str(root),
        "primary_worktree": str(primary),
        "base": base,
        "worktrees": [audit_one(item, primary=primary, base=base) for item in records],
    }


def sanitize_key(value: str) -> str:
    key = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-.")
    return key[:120] or "detached"


def checkpoint_dir(repo: Path) -> Path:
    return common_git_dir(repo) / "codex" / "github-backlog-worktree-drain"


def checkpoint_key(repo: Path, explicit: str | None = None) -> str:
    if explicit:
        return sanitize_key(explicit)
    branch = git(repo, "branch", "--show-current", check=False).stdout.strip()
    if branch:
        return sanitize_key(branch)
    head = git(repo, "rev-parse", "--short=12", "HEAD").stdout.strip()
    return sanitize_key(f"detached-{head}")


def checkpoint_path(repo: Path, key: str | None = None) -> Path:
    return checkpoint_dir(repo) / f"{checkpoint_key(repo, key)}.json"


def ensure_secret_free(values: list[str]) -> None:
    for value in values:
        if SENSITIVE_VALUE.search(value):
            raise ValueError("Checkpoint text appears to contain a secret or token")


def redact_sensitive(value: Any) -> Any:
    if isinstance(value, str):
        return "<redacted-sensitive-value>" if SENSITIVE_VALUE.search(value) else value
    if isinstance(value, list):
        return [redact_sensitive(item) for item in value]
    if isinstance(value, dict):
        return {key: redact_sensitive(item) for key, item in value.items()}
    return value


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def checkpoint_set(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    target = Path(args.worktree).resolve() if args.worktree else repository_root(repo)
    values = [
        args.phase,
        args.status,
        args.summary,
        args.next_action,
        *args.evidence,
        *args.unconfirmed,
    ]
    ensure_secret_free(values)
    snapshot = redact_sensitive(audit(repo, target, args.base)["worktrees"][0])
    state = {
        "schema_version": 1,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "key": checkpoint_key(target, args.key),
        "phase": args.phase,
        "status": args.status,
        "issue": args.issue,
        "pr": args.pr,
        "summary": args.summary,
        "evidence": args.evidence,
        "unconfirmed_remote_actions": args.unconfirmed,
        "next_action": args.next_action,
        "worktree": snapshot,
    }
    path = checkpoint_path(target, args.key)
    write_json_atomic(path, state)
    print(json.dumps({"saved": str(path), "state": state}, ensure_ascii=False, indent=2))
    return 0


def checkpoint_show(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    path = checkpoint_path(repo, args.key)
    if not path.exists():
        print(json.dumps({"checkpoint": None, "path": str(path)}, indent=2))
        return 0
    print(path.read_text(encoding="utf-8"), end="")
    return 0


def checkpoint_list(args: argparse.Namespace) -> int:
    directory = checkpoint_dir(Path(args.repo).resolve())
    checkpoints: list[dict[str, Any]] = []
    if directory.exists():
        for path in sorted(directory.glob("*.json")):
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                checkpoints.append(
                    {
                        "path": str(path),
                        "key": value.get("key"),
                        "status": value.get("status"),
                        "phase": value.get("phase"),
                        "updated_at": value.get("updated_at"),
                        "next_action": value.get("next_action"),
                    }
                )
            except (OSError, json.JSONDecodeError) as exc:
                checkpoints.append({"path": str(path), "error": str(exc)})
    print(json.dumps({"directory": str(directory), "checkpoints": checkpoints}, indent=2))
    return 0


def checkpoint_clear(args: argparse.Namespace) -> int:
    if not args.confirm_cleaned:
        raise ValueError("Use --confirm-cleaned only after merged cleanup is verified")
    repo = Path(args.repo).resolve()
    path = checkpoint_path(repo, args.key)
    if path.exists():
        path.unlink()
        print(json.dumps({"removed": str(path)}, indent=2))
    else:
        print(json.dumps({"removed": None, "path": str(path)}, indent=2))
    return 0


def fetch_pr(repo_name: str, pr: int) -> dict[str, Any]:
    proc = run(
        [
            "gh",
            "pr",
            "view",
            str(pr),
            "--repo",
            repo_name,
            "--json",
            "number,state,mergedAt,headRefName,headRefOid,baseRefName,url",
        ],
        check=False,
    )
    if proc.returncode != 0:
        raise CommandError(proc.stderr.strip() or "Unable to read PR metadata")
    return json.loads(proc.stdout)


def cleanup_check(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    target = Path(args.worktree).resolve()
    snapshot = audit(repo, target, args.base)
    worktree = snapshot["worktrees"][0]
    checks: list[dict[str, Any]] = []

    def add(name: str, passed: bool, detail: str) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    add("registered", True, "Target is registered")
    add("not_primary", not worktree["primary"], "Primary worktrees are never removable")
    add("clean", worktree["clean"], f"dirty_paths={worktree['dirty_paths']}")
    add(
        "no_active_git_operation",
        not worktree["active_git_operations"],
        f"markers={worktree['active_git_operations']}",
    )
    if args.expected_head:
        add(
            "expected_head",
            worktree["head"] == args.expected_head,
            f"actual={worktree['head']} expected={args.expected_head}",
        )

    merge_proven = worktree["merged_into_base"]
    merge_detail = f"HEAD ancestor of {args.base}: {merge_proven}"
    pr_data: dict[str, Any] | None = None
    if args.pr is not None:
        if not args.github_repo:
            raise ValueError("--github-repo is required with --pr")
        pr_data = fetch_pr(args.github_repo, args.pr)
        merge_proven = (
            pr_data.get("mergedAt") is not None
            and pr_data.get("state") == "MERGED"
            and pr_data.get("headRefName") == worktree["branch"]
            and pr_data.get("headRefOid") == worktree["head"]
            and pr_data.get("baseRefName") == args.base.removeprefix("origin/")
        )
        merge_detail = (
            f"PR #{args.pr} state={pr_data.get('state')} mergedAt={pr_data.get('mergedAt')} "
            f"head={pr_data.get('headRefName')}@{pr_data.get('headRefOid')}"
        )
    add("merge_proven", merge_proven, merge_detail)

    safe = all(item["passed"] for item in checks)
    output = {
        "safe": safe,
        "worktree": worktree,
        "checks": checks,
        "pr": pr_data,
        "next_command": f"git worktree remove -- {target}" if safe else None,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if safe else 3


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    audit_parser = subparsers.add_parser("audit", help="Read-only worktree audit")
    audit_parser.add_argument("--repo", default=".")
    audit_parser.add_argument("--target")
    audit_parser.add_argument("--base", default="origin/main")

    checkpoint_parser = subparsers.add_parser("checkpoint", help="Manage resume checkpoints")
    checkpoint_subparsers = checkpoint_parser.add_subparsers(
        dest="checkpoint_command",
        required=True,
    )
    set_parser = checkpoint_subparsers.add_parser("set")
    set_parser.add_argument("--repo", default=".")
    set_parser.add_argument("--worktree")
    set_parser.add_argument("--base", default="origin/main")
    set_parser.add_argument("--key")
    set_parser.add_argument("--phase", required=True)
    set_parser.add_argument("--status", choices=CHECKPOINT_STATUSES, required=True)
    set_parser.add_argument("--issue", type=int)
    set_parser.add_argument("--pr", type=int)
    set_parser.add_argument("--summary", required=True)
    set_parser.add_argument("--evidence", action="append", default=[])
    set_parser.add_argument("--unconfirmed", action="append", default=[])
    set_parser.add_argument("--next-action", required=True)
    show_parser = checkpoint_subparsers.add_parser("show")
    show_parser.add_argument("--repo", default=".")
    show_parser.add_argument("--key")
    list_parser = checkpoint_subparsers.add_parser("list")
    list_parser.add_argument("--repo", default=".")
    clear_parser = checkpoint_subparsers.add_parser("clear")
    clear_parser.add_argument("--repo", default=".")
    clear_parser.add_argument("--key")
    clear_parser.add_argument("--confirm-cleaned", action="store_true")

    cleanup_parser = subparsers.add_parser("cleanup-check", help="Prove removal safety")
    cleanup_parser.add_argument("--repo", default=".")
    cleanup_parser.add_argument("--worktree", required=True)
    cleanup_parser.add_argument("--base", default="origin/main")
    cleanup_parser.add_argument("--expected-head")
    cleanup_parser.add_argument("--github-repo")
    cleanup_parser.add_argument("--pr", type=int)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "audit":
            target = Path(args.target) if args.target else None
            payload = audit(Path(args.repo), target, args.base)
            print(json.dumps(payload, ensure_ascii=False, indent=2))
            return 0
        if args.command == "cleanup-check":
            return cleanup_check(args)
        if args.checkpoint_command == "set":
            return checkpoint_set(args)
        if args.checkpoint_command == "show":
            return checkpoint_show(args)
        if args.checkpoint_command == "list":
            return checkpoint_list(args)
        return checkpoint_clear(args)
    except (CommandError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
