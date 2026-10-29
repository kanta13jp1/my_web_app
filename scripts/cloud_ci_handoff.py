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
from urllib.parse import quote


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
    clean: bool | None
    workflow: str
    ready: bool
    reasons: tuple[str, ...]
    profile: str | None = None
    repository: str | None = None
    source: str = "local"


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


def remote_api(path: str, root: Path, runner: Runner) -> Any:
    payload = json.loads(_require(
        runner(["gh", "api", "--hostname", "github.com", path], root),
        "remote GitHub preflight",
    ))
    if not isinstance(payload, dict):
        raise RuntimeError("Remote GitHub preflight returned a non-object payload")
    return payload


def inspect_remote_handoff(
    root: Path,
    repository: str,
    branch: str,
    head_sha: str,
    workflow: str,
    profile: str,
    runner: Runner = run_command,
) -> HandoffState:
    """Inspect only committed GitHub source; never inspect/reset a local checkout."""
    reasons: list[str] = []
    if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+", repository)
            or repository.rsplit("/", 1)[-1] in {".", ".."}):
        reasons.append("remote repository must be an explicit github.com owner/name")
    if (
        not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", branch)
        or any(not part or part.startswith(".") or part.endswith((".", ".lock"))
               for part in branch.split("/"))
        or ".." in branch
        or branch == "HEAD"
        or branch in PROTECTED_BRANCHES
    ):
        reasons.append("remote branch must be an explicit unprotected branch")
    if not FULL_SHA.fullmatch(head_sha):
        reasons.append("expected remote HEAD must be a lowercase 40-character SHA")
    # Keep the new remote-only path limited to the requested formatter use case.
    if workflow != CLOUD_DEVELOPMENT_WORKFLOW or profile != "format":
        reasons.append("remote-only handoff currently supports cloud-development format only")
    remote_sha: str | None = None
    if not reasons:
        authenticated_id = _require(
            runner(["gh", "api", "--hostname", "github.com", "user", "--jq", ".id"], root),
            "GitHub authentication check",
        )
        if not authenticated_id.isdigit():
            raise RuntimeError("GitHub authentication check did not identify an account")
        metadata = remote_api(f"repos/{repository}", root, runner)
        if metadata.get("full_name", "").lower() != repository.lower():
            reasons.append("remote repository identity changed")
        if metadata.get("default_branch") == branch:
            reasons.append("remote default branch cannot be handed off")
        if metadata.get("permissions", {}).get("push") is not True:
            reasons.append("repository write permission is unavailable")
        ref = remote_api(
            f"repos/{repository}/git/ref/heads/{quote(branch, safe='')}", root, runner,
        )
        if ref.get("ref") != f"refs/heads/{branch}" or ref.get("object", {}).get("type") != "commit":
            reasons.append("remote ref is not the requested branch commit")
        remote_sha = ref.get("object", {}).get("sha")
        if remote_sha != head_sha:
            reasons.append("remote branch does not match expected HEAD")
        info = remote_api(
            f"repos/{repository}/actions/workflows/{workflow}", root, runner,
        )
        if info.get("state") != "active" or info.get("path") != f".github/workflows/{workflow}":
            reasons.append("requested workflow is missing, inactive, or has a different path")
    return HandoffState(
        root=str(root), branch=branch, head_sha=head_sha, remote_sha=remote_sha,
        clean=None, workflow=workflow, ready=not reasons, reasons=tuple(reasons),
        profile=profile, repository=repository, source="remote",
    )


def repository_args(state: HandoffState) -> list[str]:
    # Pin the host too; GH_HOST or the caller's unrelated cwd must not retarget a run.
    return ["--repo", f"github.com/{state.repository}"] if state.repository else []


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
    command.extend(repository_args(state))
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
            *repository_args(state),
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
    require_unique: bool = False,
) -> dict[str, Any] | None:
    candidates = []
    for run in runs:
        database_id = run.get("databaseId")
        if (
            isinstance(database_id, int)
            and database_id not in previous_ids
            and str(run.get("headSha", "")).lower() == head_sha.lower()
        ):
            candidates.append(run)
    if require_unique and len(candidates) > 1:
        raise RuntimeError("Multiple new runs match the remote HEAD; inspect history before retrying")
    return candidates[0] if candidates else None


def dispatch_and_locate(
    state: HandoffState,
    *,
    timeout_seconds: float,
    poll_seconds: float,
    runner: Runner = run_command,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    if not state.ready:
        raise RuntimeError("Handoff preflight is not ready")
    root = Path(state.root)
    before = list_runs(state, root, runner)
    previous_ids = {
        item["databaseId"]
        for item in before
        if isinstance(item.get("databaseId"), int)
    }
    if state.repository:
        # Fence branch movement between the original preflight and dispatch.
        fresh = inspect_remote_handoff(
            root, state.repository, state.branch, state.head_sha,
            state.workflow, state.profile or "", runner,
        )
        if not fresh.ready:
            raise RuntimeError("Remote preflight changed before dispatch: " + "; ".join(fresh.reasons))
    dispatched = runner(dispatch_command(state), root)
    if dispatched.code != 0:
        raise RuntimeError(
            "Workflow dispatch failed or its outcome is unknown; inspect run history "
            "before retrying. " + (dispatched.stderr or dispatched.stdout)
        )

    deadline = time.monotonic() + timeout_seconds
    while True:
        run = select_new_exact_run(
            list_runs(state, root, runner),
            head_sha=state.head_sha,
            previous_ids=previous_ids,
            require_unique=state.repository is not None,
        )
        if run is not None:
            return run
        if time.monotonic() >= deadline:
            raise RuntimeError(
                "timed out waiting for a new workflow_dispatch run at the exact HEAD; "
                "the request was sent, so inspect run history before retrying"
            )
        sleeper(poll_seconds)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--workflow", default=CLOUD_DEVELOPMENT_WORKFLOW)
    parser.add_argument("--remote-repo", help="Explicit github.com owner/name; no local Git source.")
    parser.add_argument("--remote-branch", help="Existing unprotected remote branch.")
    parser.add_argument("--expected-head-sha", help="Exact committed remote SHA for formatter handoff.")
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
    args = parser.parse_args(argv)
    remote = (args.remote_repo, args.remote_branch, args.expected_head_sha)
    if any(remote) and not all(remote):
        parser.error("--remote-repo, --remote-branch and --expected-head-sha must be supplied together")
    return args


def _emit(payload: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return
    state = payload["handoff"]
    print(f"Cloud CI handoff: {payload['status'].upper()}")
    print(f"- Source: {state['source']}")
    if state.get("repository"):
        print(f"- Repository: github.com/{state['repository']}")
        print("- Local checkout: not inspected or modified")
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
        if args.remote_repo:
            state = inspect_remote_handoff(
                args.repo_root.resolve(), args.remote_repo, args.remote_branch,
                args.expected_head_sha, args.workflow, profile or "",
            )
        else:
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
                    ["gh", "run", "watch", str(run_id), "--exit-status", *repository_args(state)],
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
