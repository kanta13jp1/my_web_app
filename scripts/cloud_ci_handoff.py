#!/usr/bin/env python3
"""Dispatch and track an exact pushed Git HEAD in GitHub Actions."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Sequence


FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
PROTECTED_BRANCHES = frozenset({"main", "master", "staging", "develop"})


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class HandoffState:
    root: str
    branch: str
    head_sha: str
    remote_sha: str | None
    clean: bool
    workflow: str
    ready: bool
    reasons: tuple[str, ...]


Runner = Callable[[Sequence[str], Path], CommandResult]


def run_command(args: Sequence[str], cwd: Path) -> CommandResult:
    try:
        proc = subprocess.run(
            list(args),
            cwd=str(cwd),
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except (FileNotFoundError, PermissionError, OSError) as exc:
        return CommandResult(127, "", str(exc))
    return CommandResult(
        proc.returncode,
        (proc.stdout or "").strip(),
        (proc.stderr or "").strip(),
    )


def _require(result: CommandResult, label: str) -> str:
    if result.code != 0:
        detail = result.stderr or result.stdout or "unknown error"
        raise RuntimeError(f"{label} failed: {detail}")
    return result.stdout


def readiness_reasons(
    *,
    branch: str,
    head_sha: str,
    remote_sha: str | None,
    clean: bool,
    gh_available: bool,
) -> tuple[str, ...]:
    reasons: list[str] = []
    if not branch or branch == "HEAD":
        reasons.append("detached HEAD cannot be handed off")
    elif branch in PROTECTED_BRANCHES:
        reasons.append(f"protected branch {branch!r} cannot be handed off")
    if not FULL_SHA.fullmatch(head_sha):
        reasons.append("local HEAD is not a full 40-character SHA")
    if not clean:
        reasons.append("working tree is dirty; commit the intended change first")
    if remote_sha is None:
        reasons.append("the current branch does not exist on origin")
    elif remote_sha != head_sha:
        reasons.append("origin branch does not match local HEAD; push the branch first")
    if not gh_available:
        reasons.append("GitHub CLI is unavailable")
    return tuple(reasons)


def inspect_handoff(
    repo_root: Path,
    workflow: str,
    runner: Runner = run_command,
) -> HandoffState:
    root_text = _require(
        runner(["git", "rev-parse", "--show-toplevel"], repo_root),
        "git root lookup",
    )
    root = Path(root_text)
    branch = _require(
        runner(["git", "branch", "--show-current"], root),
        "branch lookup",
    )
    head_sha = _require(
        runner(["git", "rev-parse", "HEAD"], root),
        "HEAD lookup",
    ).lower()
    status = _require(
        runner(["git", "status", "--porcelain", "--untracked-files=normal"], root),
        "working-tree status",
    )
    remote_text = _require(
        runner(
            ["git", "ls-remote", "--heads", "origin", f"refs/heads/{branch}"],
            root,
        ),
        "origin branch lookup",
    )
    remote_sha: str | None = None
    if remote_text:
        candidate = remote_text.split()[0].lower()
        if FULL_SHA.fullmatch(candidate):
            remote_sha = candidate
    gh_available = runner(["gh", "--version"], root).code == 0
    reasons = readiness_reasons(
        branch=branch,
        head_sha=head_sha,
        remote_sha=remote_sha,
        clean=not status,
        gh_available=gh_available,
    )
    return HandoffState(
        root=str(root),
        branch=branch,
        head_sha=head_sha,
        remote_sha=remote_sha,
        clean=not status,
        workflow=workflow,
        ready=not reasons,
        reasons=reasons,
    )


def dispatch_command(state: HandoffState) -> list[str]:
    return [
        "gh",
        "workflow",
        "run",
        state.workflow,
        "--ref",
        state.branch,
        "-f",
        f"expected_head_sha={state.head_sha}",
    ]


def list_runs(
    state: HandoffState,
    root: Path,
    runner: Runner = run_command,
) -> list[dict[str, Any]]:
    result = runner(
        [
            "gh",
            "run",
            "list",
            "--workflow",
            state.workflow,
            "--branch",
            state.branch,
            "--event",
            "workflow_dispatch",
            "--limit",
            "20",
            "--json",
            "databaseId,headSha,status,conclusion,url,createdAt",
        ],
        root,
    )
    raw = _require(result, "workflow run lookup")
    payload = json.loads(raw or "[]")
    if not isinstance(payload, list):
        raise RuntimeError("workflow run lookup returned a non-list payload")
    return [item for item in payload if isinstance(item, dict)]


def select_new_exact_run(
    runs: list[dict[str, Any]],
    *,
    head_sha: str,
    previous_ids: set[int],
) -> dict[str, Any] | None:
    for run in runs:
        database_id = run.get("databaseId")
        if (
            isinstance(database_id, int)
            and database_id not in previous_ids
            and str(run.get("headSha", "")).lower() == head_sha.lower()
        ):
            return run
    return None


def dispatch_and_locate(
    state: HandoffState,
    *,
    timeout_seconds: float,
    poll_seconds: float,
    runner: Runner = run_command,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    root = Path(state.root)
    before = list_runs(state, root, runner)
    previous_ids = {
        item["databaseId"]
        for item in before
        if isinstance(item.get("databaseId"), int)
    }
    _require(runner(dispatch_command(state), root), "workflow dispatch")

    deadline = time.monotonic() + timeout_seconds
    while True:
        run = select_new_exact_run(
            list_runs(state, root, runner),
            head_sha=state.head_sha,
            previous_ids=previous_ids,
        )
        if run is not None:
            return run
        if time.monotonic() >= deadline:
            raise RuntimeError(
                "timed out waiting for a new workflow_dispatch run at the exact HEAD"
            )
        sleeper(poll_seconds)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--workflow", default="ci.yml")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Dispatch the workflow after all exact-HEAD checks pass.",
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Wait for the dispatched run and return its exit status.",
    )
    parser.add_argument("--timeout-seconds", type=float, default=90.0)
    parser.add_argument("--poll-seconds", type=float, default=2.0)
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser.parse_args(argv)


def _emit(payload: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return
    state = payload["handoff"]
    print(f"Cloud CI handoff: {payload['status'].upper()}")
    print(f"- Branch: {state['branch']}")
    print(f"- Exact HEAD: {state['head_sha']}")
    print(f"- Origin HEAD: {state['remote_sha'] or 'missing'}")
    print(f"- Workflow: {state['workflow']}")
    for reason in state["reasons"]:
        print(f"- Blocker: {reason}")
    run = payload.get("run")
    if isinstance(run, dict):
        print(f"- Run: {run.get('url', run.get('databaseId', 'unknown'))}")


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    if args.watch and not args.execute:
        print("--watch requires --execute", file=sys.stderr)
        return 2
    try:
        state = inspect_handoff(args.repo_root.resolve(), args.workflow)
        payload: dict[str, Any] = {
            "status": "ready" if state.ready else "blocked",
            "handoff": {**asdict(state), "reasons": list(state.reasons)},
        }
        if not state.ready:
            _emit(payload, args.as_json)
            return 2
        if args.execute:
            run = dispatch_and_locate(
                state,
                timeout_seconds=args.timeout_seconds,
                poll_seconds=args.poll_seconds,
            )
            payload["status"] = "dispatched"
            payload["run"] = run
            _emit(payload, args.as_json)
            if args.watch:
                run_id = run.get("databaseId")
                if not isinstance(run_id, int):
                    print("dispatched run has no databaseId", file=sys.stderr)
                    return 2
                result = run_command(
                    ["gh", "run", "watch", str(run_id), "--exit-status"],
                    Path(state.root),
                )
                if result.stdout:
                    print(result.stdout)
                if result.stderr:
                    print(result.stderr, file=sys.stderr)
                return result.code
            return 0
        _emit(payload, args.as_json)
        return 0
    except (RuntimeError, json.JSONDecodeError) as exc:
        print(f"cloud CI handoff failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
