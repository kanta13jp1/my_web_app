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
CLOUD_DEVELOPMENT_WORKFLOW = "cloud-development.yml"
CLOUD_PROFILES = ("workspace", "format", "analyze", "test", "web-build", "full")


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
    profile: str | None = None


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
    profile: str | None = None,
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
        profile=profile,
    )


def dispatch_command(state: HandoffState) -> list[str]:
    command = [
        "gh",
        "workflow",
        "run",
        state.workflow,
        "--ref",
        state.branch,
        "-f",
        f"expected_head_sha={state.head_sha}",
    ]
    if state.profile is not None:
        command.extend(["-f", f"profile={state.profile}"])
    return command


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



# PR5925 release assessment is intentionally non-executing. Its evidence
# container is not an authentication boundary; production dispatch remains
# unavailable until atomic ref/run provenance and queue fencing are solved.
@dataclass(frozen=True)
class Release5925Evidence:
    branch: str
    head_sha: str
    tree_sha: str
    parent_sha: str
    workflow_blob: str
    changed_blobs: dict[str, str]
    pr_merged: bool
    pr_merge_sha: str
    live_sha: str
    hold_value: str
    branch_protected: bool | None
    effective_rules: tuple[str, ...] | None
    active_or_queued_runs: tuple[str, ...] | None
    fifo_lease_verified: bool
    approved_release: bool
    scope: str
    profile: str


_RELEASE_5925_BRANCH = "codex/approved-5925-calendar-release"
_RELEASE_5925_HEAD = "9bdb9933a16cb9b8dce517c2bf7c61fafc5969e6"
_RELEASE_5925_TREE = "b510e0d508dfafdb1d0a8c9e9e4fc6a46312f98a"
_RELEASE_5925_BASE = "237d9290183c3bb3df73388ec9cf4563bb0186ef"
_RELEASE_5925_MERGE = "fa105154b7a09c291fd739d3ae1245cebb90069d"
_RELEASE_5925_WORKFLOW = "372ca0816e65fcf972a959be12c67a0479684e82"
_RELEASE_5925_CHANGED_BLOBS = {
    ".github/workflows/cloud-development.yml": _RELEASE_5925_WORKFLOW,
    "lib/models/asset_calendar_reflection.dart": "431d6730e832695e536690a8e1d4499c1da86f32",
    "test/models/asset_calendar_reflection_test.dart": "f0dafa73fb05e8ea79baa30a0f42212b5e1144ed",
    "test/e2e/asset_calendar_projection_test.dart": "9ef6ce7f2f83697d4583d6b40aaa03901b3d3c19",
}


def release_5925_blockers(evidence: Release5925Evidence) -> tuple[str, ...]:
    # Tree pins repo-local workflow dependencies too; it does not pin external
    # downloads, prove API freshness, or prevent ref changes after inspection.
    checks = (
        (evidence.branch == _RELEASE_5925_BRANCH, "unexpected release branch"),
        (evidence.head_sha == _RELEASE_5925_HEAD, "unexpected candidate head"),
        (evidence.tree_sha == _RELEASE_5925_TREE, "candidate tree mismatch"),
        (evidence.parent_sha == _RELEASE_5925_BASE, "candidate parent mismatch"),
        (evidence.workflow_blob == _RELEASE_5925_WORKFLOW, "workflow blob mismatch"),
        (evidence.changed_blobs == _RELEASE_5925_CHANGED_BLOBS, "release paths or blobs differ"),
        (evidence.pr_merged is True and evidence.pr_merge_sha == _RELEASE_5925_MERGE, "PR merge unconfirmed"),
        (evidence.live_sha == _RELEASE_5925_BASE, "production base changed or unknown"),
        (evidence.hold_value == "false", "production hold active or unknown"),
        (evidence.branch_protected is False, "branch protection present or unknown"),
        (evidence.effective_rules == (), "branch rules present or unknown"),
        (evidence.active_or_queued_runs == (), "existing runs present or unknown"),
        (evidence.fifo_lease_verified is True, "shared FIFO lease unverified"),
        (evidence.approved_release is True, "release authorization unverified"),
        (evidence.scope == "web_only" and evidence.profile == "full", "release scope/profile mismatch"),
    )
    reasons = [reason for ok, reason in checks if not ok]
    # These cannot be established for the fixed 9bdb candidate by supplied
    # booleans: no operation input/run-name, no atomic immutable-ref guarantee,
    # and no shared FIFO binding for all dispatchers.
    reasons.extend((
        "candidate workflow has no verifiable operation ID binding",
        "FIFO binding and immediate ref/run rechecks are unimplemented",
        "approved release dispatch is unimplemented",
    ))
    return tuple(reasons)



def create_release_5925_pending_journal(journal_path: Path, operation_id: str) -> None:
    # Exclusive creation makes an existing pending or ambiguous operation
    # durable evidence, never permission to retry or replace it.
    import os

    if not re.fullmatch(r"[0-9a-f]{32}", operation_id):
        raise ValueError("operation ID must be 32 lowercase hex characters")
    data = json.dumps({
        "operation_id": operation_id,
        "head": _RELEASE_5925_HEAD,
        "workflow": CLOUD_DEVELOPMENT_WORKFLOW,
        "status": "pending_or_unknown",
    }, sort_keys=True).encode("utf-8")
    fd = os.open(str(journal_path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as output:
        output.write(data)
        output.flush()
        os.fsync(output.fileno())


def parse_release_5925_run_id(http_status: int, payload: Any) -> int:
    # Failed/lost/malformed replies must stay unknown, not be auto-retried.
    if http_status != 200 or not isinstance(payload, dict):
        raise RuntimeError("dispatch outcome unknown; do not retry")
    run_id = payload.get("workflow_run_id")
    if isinstance(run_id, bool) or not isinstance(run_id, int) or run_id <= 0:
        raise RuntimeError("dispatch outcome unknown; do not retry")
    return run_id


def dispatch_release_5925(*args: Any, **kwargs: Any) -> None:
    raise RuntimeError("PR5925 release dispatch is not implemented; no request sent")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--workflow", default=CLOUD_DEVELOPMENT_WORKFLOW)
    parser.add_argument(
        "--profile",
        choices=CLOUD_PROFILES,
        default="full",
        help=(
            "Cloud development scope. Used only with cloud-development.yml; "
            "defaults to full."
        ),
    )
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
    if state.get("profile"):
        print(f"- Profile: {state['profile']}")
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
        profile = (
            args.profile
            if Path(args.workflow).name == CLOUD_DEVELOPMENT_WORKFLOW
            else None
        )
        state = inspect_handoff(
            args.repo_root.resolve(),
            args.workflow,
            profile=profile,
        )
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
