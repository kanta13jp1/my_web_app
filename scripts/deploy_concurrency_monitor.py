#!/usr/bin/env python3
"""Monitor GitHub Actions production deploy concurrency and main-head sync (#2678).

Inspects static concurrency contracts across deployment workflows (`cancel-in-progress: false`,
commit-SHA-pinned production checkout, CI push/workflow_call non-cancellation) and evaluates
`deploy-prod.yml` run history against the target `main` commit SHA to detect unintended
concurrency cancellations, failed deploys needing rerun, and unsynced main commits without
arbitrary shell execution or secret leakage.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


REPO_SLUG_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
BRANCH_RE = re.compile(r"^[A-Za-z0-9_./-]{1,128}$")
WORKFLOW_FILE_RE = re.compile(r"^[A-Za-z0-9_.-]+\.ya?ml$")
FULL_SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")
VALID_RUN_STATUSES = {
    "completed",
    "in_progress",
    "queued",
    "requested",
    "waiting",
    "pending",
}
RETRYABLE_CONCLUSIONS = {"failure", "timed_out"}
BAD_CONCLUSIONS = {
    "action_required",
    "cancelled",
    "failure",
    "startup_failure",
    "timed_out",
}
IN_PROGRESS_STATUSES = {"in_progress", "queued", "requested", "waiting", "pending"}

REQUIRED_SERIAL_DEPLOY_WORKFLOWS = (
    ".github/workflows/deploy-prod.yml",
    ".github/workflows/deploy-core-hub.yml",
    ".github/workflows/deploy-dev.yml",
    ".github/workflows/deploy-staging.yml",
)


def _parse_top_level_concurrency(text: str) -> tuple[str, str]:
    lines = text.splitlines()
    group_val = ""
    cancel_val = ""
    in_concurrency = False
    for raw in lines:
        if re.match(r"^[A-Za-z0-9_-]+:", raw):
            in_concurrency = raw.startswith("concurrency:")
            continue
        if not in_concurrency:
            continue
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if raw.startswith("  group:"):
            group_val = raw.split(":", 1)[1].split("#", 1)[0].strip().strip("'\"")
        elif raw.startswith("  cancel-in-progress:"):
            cancel_val = raw.split(":", 1)[1].split("#", 1)[0].strip().strip("'\"")
    return group_val, cancel_val


def inspect_workflow_concurrency(repo_root: Path) -> dict[str, Any]:
    """Verify static concurrency serialization and SHA-pinned checkout across deploy workflows."""
    contracts: list[dict[str, Any]] = []
    all_violations: list[str] = []

    for rel in REQUIRED_SERIAL_DEPLOY_WORKFLOWS:
        wf_path = repo_root / rel
        if not wf_path.exists():
            msg = f"{rel}: missing required deployment workflow"
            all_violations.append(msg)
            contracts.append(
                {
                    "path": rel,
                    "group": "",
                    "cancel_in_progress": "",
                    "valid": False,
                    "violations": [msg],
                },
            )
            continue

        text = wf_path.read_text(encoding="utf-8-sig")
        group_val, cancel_val = _parse_top_level_concurrency(text)
        wf_violations: list[str] = []
        if not group_val:
            wf_violations.append(f"{rel}: missing concurrency.group")
        if cancel_val.lower() != "false":
            wf_violations.append(
                f"{rel}: cancel-in-progress must be `false` (got `{cancel_val or 'missing'}`)",
            )
        if rel == ".github/workflows/deploy-prod.yml":
            if group_val != "deploy-production":
                wf_violations.append(
                    f"{rel}: expected concurrency.group `deploy-production` (got `{group_val}`)",
                )
            if "$GITHUB_SHA" not in text or "FETCH_HEAD" not in text:
                wf_violations.append(
                    f"{rel}: production checkout must fetch exact $GITHUB_SHA into FETCH_HEAD",
                )

        all_violations.extend(wf_violations)
        contracts.append(
            {
                "path": rel,
                "group": group_val,
                "cancel_in_progress": cancel_val,
                "valid": len(wf_violations) == 0,
                "violations": wf_violations,
            },
        )

    ci_rel = ".github/workflows/ci.yml"
    ci_path = repo_root / ci_rel
    if ci_path.exists():
        ci_text = ci_path.read_text(encoding="utf-8-sig")
        ci_group, ci_cancel = _parse_top_level_concurrency(ci_text)
        ci_violations: list[str] = []
        if not ci_group:
            ci_violations.append(f"{ci_rel}: missing concurrency.group")
        if ci_cancel.lower() == "true":
            ci_violations.append(
                f"{ci_rel}: unconditional cancel-in-progress: true cancels push/workflow_call runs",
            )
        elif ci_cancel.lower() != "false":
            if "pull_request" not in ci_cancel or "push" in ci_cancel or "workflow_call" in ci_cancel:
                ci_violations.append(
                    f"{ci_rel}: concurrency expression must only cancel pull_request/workflow_dispatch runs",
                )
        all_violations.extend(ci_violations)
        contracts.append(
            {
                "path": ci_rel,
                "group": ci_group,
                "cancel_in_progress": ci_cancel,
                "valid": len(ci_violations) == 0,
                "violations": ci_violations,
            },
        )

    return {
        "contracts_ok": len(all_violations) == 0,
        "checked_workflows": len(contracts),
        "violations": all_violations,
        "workflows": contracts,
    }


def _parse_iso_ts(value: Any) -> float:
    text = str(value or "").strip()
    if not text:
        return 0.0
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(text).astimezone(timezone.utc).timestamp()
    except ValueError:
        return 0.0


def normalize_run(raw: dict[str, Any]) -> dict[str, Any]:
    """Normalize either `gh run list --json` or GitHub REST `/actions/runs` entries."""
    if not isinstance(raw, dict):
        raise ValueError("workflow run entry must be a JSON object")

    raw_id = raw.get("databaseId") if raw.get("databaseId") is not None else raw.get("id")
    if not isinstance(raw_id, int) or isinstance(raw_id, bool) or raw_id <= 0:
        raise ValueError(f"workflow run has invalid run id: {raw_id!r}")

    raw_sha = str(raw.get("headSha") or raw.get("head_sha") or "").strip().lower()
    if not FULL_SHA_RE.fullmatch(raw_sha):
        raise ValueError(f"workflow run {raw_id} has invalid headSha: {raw_sha!r}")

    status = str(raw.get("status") or "").strip().lower()
    if status not in VALID_RUN_STATUSES:
        raise ValueError(f"workflow run {raw_id} has invalid status: {status!r}")

    conclusion_raw = raw.get("conclusion")
    conclusion = str(conclusion_raw).strip().lower() if conclusion_raw else ""

    raw_attempt = raw.get("attempt") if raw.get("attempt") is not None else raw.get("run_attempt", 1)
    try:
        attempt = int(raw_attempt)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"workflow run {raw_id} has invalid attempt: {raw_attempt!r}") from exc

    created_at = str(raw.get("createdAt") or raw.get("created_at") or "").strip()
    updated_at = str(raw.get("updatedAt") or raw.get("updated_at") or created_at).strip()
    event = str(raw.get("event") or "push").strip()
    url = str(raw.get("url") or raw.get("html_url") or "").strip()

    return {
        "databaseId": raw_id,
        "headSha": raw_sha,
        "status": status,
        "conclusion": conclusion,
        "attempt": max(1, attempt),
        "event": event,
        "createdAt": created_at,
        "updatedAt": updated_at,
        "url": url,
        "_created_epoch": _parse_iso_ts(created_at),
    }


def evaluate_deploy_state(
    raw_runs: list[dict[str, Any]],
    *,
    main_sha: str,
    contract_audit: dict[str, Any],
    workflow_file: str = "deploy-prod.yml",
    branch: str = "main",
    max_attempts: int = 2,
) -> dict[str, Any]:
    """Evaluate deployment synchronization, concurrency cancellations, and recovery recommendations."""
    normalized_sha = main_sha.strip().lower()
    if normalized_sha and not FULL_SHA_RE.fullmatch(normalized_sha):
        raise ValueError(f"main_sha must be a 40-char hex SHA (got {main_sha!r})")

    runs = [normalize_run(item) for item in raw_runs]
    runs.sort(key=lambda item: (item["_created_epoch"], item["databaseId"]), reverse=True)

    cancelled_runs = [r for r in runs if r["conclusion"] == "cancelled"]
    failed_runs = [r for r in runs if r["conclusion"] in {"failure", "timed_out", "action_required", "startup_failure"}]
    active_runs = [r for r in runs if r["status"] in IN_PROGRESS_STATUSES]

    if not normalized_sha and runs:
        normalized_sha = runs[0]["headSha"]

    matching_runs = [r for r in runs if r["headSha"] == normalized_sha] if normalized_sha else []
    latest_match = matching_runs[0] if matching_runs else None
    has_match_success = any(
        r["status"] == "completed" and r["conclusion"] == "success" for r in matching_runs
    )

    status = "healthy"
    synced = True
    recommended_action = "none"
    reason = "main-head-deployed"
    retry_run_id: int | None = None
    recommended_command: list[str] = []
    warnings: list[str] = []
    errors: list[str] = []

    if not contract_audit.get("contracts_ok", False):
        status = "contract_violation"
        synced = False
        recommended_action = "fix_concurrency_contract"
        reason = "workflow-concurrency-contract-violation"
        errors.extend(contract_audit.get("violations", []))
    elif not normalized_sha:
        status = "main_head_unsynced"
        synced = False
        recommended_action = "dispatch_main_deploy"
        reason = "no-main-sha-or-runs"
        recommended_command = ["gh", "workflow", "run", workflow_file, "--ref", branch]
        warnings.append(f"No deploy runs or target SHA found for `{branch}`.")
    elif has_match_success:
        status = "healthy"
        synced = True
        recommended_action = "none"
        reason = "main-head-deployed"
        if cancelled_runs:
            warnings.append(
                f"Historical concurrency cancellations detected ({len(cancelled_runs)} run(s)), "
                f"but latest target SHA {normalized_sha[:12]} succeeded cleanly.",
            )
    elif latest_match is not None and latest_match["status"] in IN_PROGRESS_STATUSES:
        older_in_progress = [
            r for r in active_runs if r["headSha"] != normalized_sha and r["status"] == "in_progress"
        ]
        if latest_match["status"] in {"queued", "waiting", "pending"} and older_in_progress:
            status = "queued_behind_active"
            recommended_action = "wait_serial_queue"
            reason = "serial-concurrency-queue-active"
        else:
            status = "in_progress"
            recommended_action = "wait"
            reason = f"deploy-{latest_match['status']}"
        synced = False
    elif latest_match is not None and latest_match["conclusion"] == "cancelled":
        status = "concurrency_cancelled"
        synced = False
        recommended_action = "dispatch_main_deploy"
        reason = "main-head-deploy-cancelled"
        retry_run_id = latest_match["databaseId"]
        recommended_command = ["gh", "workflow", "run", workflow_file, "--ref", branch]
        errors.append(
            f"Deploy run {latest_match['databaseId']} for {normalized_sha[:12]} was cancelled; "
            "production may lag behind main.",
        )
    elif latest_match is not None and latest_match["conclusion"] in BAD_CONCLUSIONS:
        synced = False
        retry_run_id = latest_match["databaseId"]
        if (
            latest_match["conclusion"] in RETRYABLE_CONCLUSIONS
            and latest_match["attempt"] < max_attempts
        ):
            status = "needs_rerun"
            recommended_action = "rerun_failed_jobs"
            reason = f"main-head-deploy-{latest_match['conclusion']}"
            recommended_command = ["gh", "run", "rerun", str(retry_run_id), "--failed"]
            warnings.append(
                f"Deploy run {retry_run_id} for {normalized_sha[:12]} ended `{latest_match['conclusion']}` "
                f"(attempt {latest_match['attempt']}/{max_attempts}); rerun recommended.",
            )
        else:
            status = "needs_manual_escalation"
            recommended_action = "inspect_deploy_failure"
            reason = f"main-head-deploy-{latest_match['conclusion']}-exhausted"
            recommended_command = ["gh", "run", "view", str(retry_run_id), "--log-failed"]
            errors.append(
                f"Deploy run {retry_run_id} for {normalized_sha[:12]} ended `{latest_match['conclusion']}` "
                f"(attempt {latest_match['attempt']}/{max_attempts}); manual inspection required.",
            )
    else:
        status = "main_head_unsynced"
        synced = False
        recommended_action = "dispatch_main_deploy"
        reason = "main-head-missing-deploy-run"
        recommended_command = ["gh", "workflow", "run", workflow_file, "--ref", branch]
        if active_runs:
            warnings.append(
                f"Main SHA {normalized_sha[:12]} has no queued/active run while "
                f"{len(active_runs)} older run(s) remain active (queue replacement risk).",
            )
        else:
            errors.append(
                f"Main SHA {normalized_sha[:12]} has no matching `{workflow_file}` run.",
            )

    if latest_match is None and runs and not matching_runs and cancelled_runs:
        warnings.append(
            f"Detected {len(cancelled_runs)} cancelled run(s) on recent history without a run for {normalized_sha[:12]}.",
        )

    def _public_run(item: dict[str, Any] | None) -> dict[str, Any] | None:
        if item is None:
            return None
        return {k: v for k, v in item.items() if not k.startswith("_")}

    return {
        "issue": 2678,
        "workflow": workflow_file,
        "branch": branch,
        "main_sha": normalized_sha,
        "status": status,
        "synced": synced,
        "reason": reason,
        "recommended_action": recommended_action,
        "recommended_command": recommended_command,
        "retry_run_id": retry_run_id,
        "runs_inspected": len(runs),
        "active_runs_count": len(active_runs),
        "cancelled_runs_count": len(cancelled_runs),
        "failed_runs_count": len(failed_runs),
        "latest_run": _public_run(runs[0] if runs else None),
        "latest_main_run": _public_run(latest_match),
        "contract_audit": contract_audit,
        "warnings": warnings,
        "errors": errors,
    }


def _validate_inputs(repo: str, workflow: str, branch: str) -> None:
    if not REPO_SLUG_RE.fullmatch(repo):
        raise ValueError(f"invalid repository slug: {repo!r}")
    if not WORKFLOW_FILE_RE.fullmatch(workflow):
        raise ValueError(f"invalid workflow file name: {workflow!r}")
    if not BRANCH_RE.fullmatch(branch) or ".." in branch:
        raise ValueError(f"invalid branch name: {branch!r}")


def _gh_env() -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("GOMAXPROCS", "1")
    env.setdefault("GOGC", "20")
    return env


def _fetch_live_runs(repo: str, workflow: str, branch: str, limit: int) -> list[dict[str, Any]]:
    _validate_inputs(repo, workflow, branch)
    cmd = [
        "gh",
        "run",
        "list",
        "--repo",
        repo,
        "--workflow",
        workflow,
        "--branch",
        branch,
        "--limit",
        str(limit),
        "--json",
        "databaseId,headSha,status,conclusion,event,createdAt,updatedAt,url,attempt",
    ]
    proc = subprocess.run(
        cmd,
        env=_gh_env(),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        shell=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"gh run list failed ({proc.returncode}): {proc.stderr.strip()}")
    payload = json.loads(proc.stdout)
    if not isinstance(payload, list):
        raise ValueError("gh run list output is not a JSON list")
    return payload


def _fetch_live_main_sha(repo: str, branch: str) -> str:
    if not REPO_SLUG_RE.fullmatch(repo):
        raise ValueError(f"invalid repository slug: {repo!r}")
    if not BRANCH_RE.fullmatch(branch) or ".." in branch:
        raise ValueError(f"invalid branch name: {branch!r}")
    proc = subprocess.run(
        ["gh", "api", f"repos/{repo}/git/ref/heads/{branch}", "--jq", ".object.sha"],
        env=_gh_env(),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        shell=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"gh api head sha failed ({proc.returncode}): {proc.stderr.strip()}")
    sha = proc.stdout.strip().lower()
    if not FULL_SHA_RE.fullmatch(sha):
        raise ValueError(f"invalid head SHA from gh api: {sha!r}")
    return sha


def _execute_recovery(
    report: dict[str, Any],
    *,
    repo: str,
    workflow: str,
    branch: str,
    dry_run: bool,
) -> dict[str, Any]:
    action = report.get("recommended_action")
    if dry_run:
        return {"attempted": False, "result": "skipped-dry-run", "action": action}
    if action not in {"rerun_failed_jobs", "dispatch_main_deploy"}:
        return {"attempted": False, "result": "no-recovery-needed", "action": action}

    _validate_inputs(repo, workflow, branch)
    if action == "rerun_failed_jobs":
        run_id = report.get("retry_run_id")
        if not isinstance(run_id, int) or run_id <= 0:
            raise ValueError(f"invalid retry_run_id: {run_id!r}")
        cmd = ["gh", "run", "rerun", str(run_id), "--failed", "--repo", repo]
    else:
        cmd = ["gh", "workflow", "run", workflow, "--ref", branch, "--repo", repo]

    proc = subprocess.run(
        cmd,
        env=_gh_env(),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        shell=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"recovery command failed ({proc.returncode}): {proc.stderr.strip()}")
    return {"attempted": True, "result": "executed", "action": action, "command": cmd}


def render_markdown(report: dict[str, Any]) -> str:
    contracts = report.get("contract_audit", {})
    lines = [
        "### Deploy Concurrency & Sync Monitor (#2678)",
        f"- Status: `{report['status']}` (`reason={report['reason']}`)",
        f"- Synced: `{report['synced']}` | Target SHA: `{report['main_sha'] or 'none'}`",
        f"- Contracts OK: `{contracts.get('contracts_ok', False)}` "
        f"(workflows checked: `{contracts.get('checked_workflows', 0)}`)",
        f"- Runs Inspected: `{report['runs_inspected']}` | Active: `{report['active_runs_count']}` | "
        f"Cancelled: `{report['cancelled_runs_count']}` | Failed: `{report['failed_runs_count']}`",
        f"- Recommended Action: `{report['recommended_action']}`",
    ]
    if report.get("recommended_command"):
        lines.append(f"- Suggested Command: `{' '.join(report['recommended_command'])}`")
    for warn in report.get("warnings", []):
        lines.append(f"- Warning: {warn}")
    for err in report.get("errors", []):
        lines.append(f"- Error: {err}")
    return "\n".join(lines) + "\n"


def emit_annotations_and_outputs(
    report: dict[str, Any],
    *,
    json_out: Path | None = None,
    markdown_out: Path | None = None,
    github_output: Path | None = None,
) -> None:
    for warn in report.get("warnings", []):
        print(f"::warning::{warn}")
    for err in report.get("errors", []):
        print(f"::error::{err}")

    md = render_markdown(report)
    print(md, end="")

    if json_out is not None:
        json_out.parent.mkdir(parents=True, exist_ok=True)
        json_out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if markdown_out is not None:
        markdown_out.parent.mkdir(parents=True, exist_ok=True)
        markdown_out.write_text(md, encoding="utf-8")
    if github_output is not None:
        github_output.parent.mkdir(parents=True, exist_ok=True)
        with github_output.open("a", encoding="utf-8") as handle:
            handle.write(f"status={report['status']}\n")
            handle.write(f"synced={str(report['synced']).lower()}\n")
            handle.write(f"recommended_action={report['recommended_action']}\n")
            handle.write(
                f"contracts_ok={str(report['contract_audit'].get('contracts_ok', False)).lower()}\n",
            )
            handle.write(f"cancelled_count={report['cancelled_runs_count']}\n")
            handle.write(f"failed_count={report['failed_runs_count']}\n")


def run_self_test(repo_root: Path) -> dict[str, Any]:
    contracts = inspect_workflow_concurrency(repo_root)
    if not contracts["contracts_ok"]:
        raise RuntimeError(f"workflow concurrency contract check failed: {contracts['violations']}")

    sha_ok = "a" * 40
    sha_old = "b" * 40

    # 1. Healthy synced run after older cancellation
    healthy_res = evaluate_deploy_state(
        [
            {
                "databaseId": 102,
                "headSha": sha_ok,
                "status": "completed",
                "conclusion": "success",
                "createdAt": "2026-11-25T01:00:00Z",
            },
            {
                "databaseId": 101,
                "headSha": sha_old,
                "status": "completed",
                "conclusion": "cancelled",
                "createdAt": "2026-11-25T00:50:00Z",
            },
        ],
        main_sha=sha_ok,
        contract_audit=contracts,
    )
    assert healthy_res["status"] == "healthy" and healthy_res["synced"] is True

    # 2. Queued behind active serial run
    queued_res = evaluate_deploy_state(
        [
            {
                "databaseId": 202,
                "headSha": sha_ok,
                "status": "queued",
                "conclusion": None,
                "createdAt": "2026-11-25T02:00:00Z",
            },
            {
                "databaseId": 201,
                "headSha": sha_old,
                "status": "in_progress",
                "conclusion": None,
                "createdAt": "2026-11-25T01:55:00Z",
            },
        ],
        main_sha=sha_ok,
        contract_audit=contracts,
    )
    assert queued_res["status"] == "queued_behind_active"
    assert queued_res["recommended_action"] == "wait_serial_queue"

    # 3. Cancelled target SHA deploy
    cancelled_res = evaluate_deploy_state(
        [
            {
                "databaseId": 301,
                "headSha": sha_ok,
                "status": "completed",
                "conclusion": "cancelled",
                "createdAt": "2026-11-25T03:00:00Z",
            },
        ],
        main_sha=sha_ok,
        contract_audit=contracts,
    )
    assert cancelled_res["status"] == "concurrency_cancelled"
    assert cancelled_res["recommended_action"] == "dispatch_main_deploy"

    # 4. Failed retryable target SHA deploy
    failed_res = evaluate_deploy_state(
        [
            {
                "databaseId": 401,
                "headSha": sha_ok,
                "status": "completed",
                "conclusion": "failure",
                "attempt": 1,
                "createdAt": "2026-11-25T04:00:00Z",
            },
        ],
        main_sha=sha_ok,
        contract_audit=contracts,
    )
    assert failed_res["status"] == "needs_rerun"
    assert failed_res["retry_run_id"] == 401

    # 5. Unsynced main head (no run for sha_ok)
    missing_res = evaluate_deploy_state(
        [
            {
                "databaseId": 501,
                "headSha": sha_old,
                "status": "completed",
                "conclusion": "success",
                "createdAt": "2026-11-25T05:00:00Z",
            },
        ],
        main_sha=sha_ok,
        contract_audit=contracts,
    )
    assert missing_res["status"] == "main_head_unsynced"

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        mutated = tmp_path / ".github" / "workflows"
        mutated.mkdir(parents=True)
        for rel in REQUIRED_SERIAL_DEPLOY_WORKFLOWS:
            target = tmp_path / rel
            content = (repo_root / rel).read_text(encoding="utf-8-sig")
            if rel.endswith("deploy-prod.yml"):
                content = content.replace("cancel-in-progress: false", "cancel-in-progress: true", 1)
            target.write_text(content, encoding="utf-8")
        bad_audit = inspect_workflow_concurrency(tmp_path)
        assert bad_audit["contracts_ok"] is False

    return {
        "self_test": "passed",
        "contracts_checked": contracts["checked_workflows"],
        "scenarios_verified": 6,
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app"),
    )
    parser.add_argument("--workflow", default="deploy-prod.yml")
    parser.add_argument("--branch", default="main")
    parser.add_argument("--main-sha", default=os.environ.get("MAIN_SHA", ""))
    parser.add_argument("--runs-json", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--max-attempts", type=int, default=2)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", default=False)
    mode.add_argument("--live", action="store_true", default=False)
    parser.add_argument("--fetch-gh", action="store_true", default=False)
    parser.add_argument("--apply-rerun", action="store_true", default=False)
    parser.add_argument("--require-synced", action="store_true", default=False)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true", default=False)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.self_test:
        result = run_self_test(args.repo_root.resolve())
        print(json.dumps(result, ensure_ascii=False))
        return 0

    dry_run = not args.live
    _validate_inputs(args.repo, args.workflow, args.branch)
    contract_audit = inspect_workflow_concurrency(args.repo_root.resolve())

    try:
        if args.runs_json is not None:
            payload = json.loads(args.runs_json.read_text(encoding="utf-8-sig"))
            raw_runs = payload["workflow_runs"] if isinstance(payload, dict) else payload
            if not isinstance(raw_runs, list):
                raise ValueError("--runs-json must contain a JSON list or {workflow_runs: [...]}")
            main_sha = args.main_sha.strip()
        elif args.live or args.fetch_gh:
            raw_runs = _fetch_live_runs(args.repo, args.workflow, args.branch, args.limit)
            main_sha = args.main_sha.strip() or _fetch_live_main_sha(args.repo, args.branch)
        else:
            raw_runs = []
            main_sha = args.main_sha.strip()

        if args.runs_json is None and not args.live and not args.fetch_gh and not main_sha:
            report = {
                "issue": 2678,
                "workflow": args.workflow,
                "branch": args.branch,
                "main_sha": "",
                "status": "contracts_ok" if contract_audit["contracts_ok"] else "contract_violation",
                "synced": contract_audit["contracts_ok"],
                "reason": "static-contracts-only-dry-run",
                "recommended_action": "none"
                if contract_audit["contracts_ok"]
                else "fix_concurrency_contract",
                "recommended_command": [],
                "retry_run_id": None,
                "runs_inspected": 0,
                "active_runs_count": 0,
                "cancelled_runs_count": 0,
                "failed_runs_count": 0,
                "latest_run": None,
                "latest_main_run": None,
                "contract_audit": contract_audit,
                "warnings": [],
                "errors": list(contract_audit.get("violations", [])),
            }
        else:
            report = evaluate_deploy_state(
                raw_runs,
                main_sha=main_sha,
                contract_audit=contract_audit,
                workflow_file=args.workflow,
                branch=args.branch,
                max_attempts=args.max_attempts,
            )
        report["dry_run"] = dry_run
        if args.apply_rerun:
            report["recovery"] = _execute_recovery(
                report,
                repo=args.repo,
                workflow=args.workflow,
                branch=args.branch,
                dry_run=dry_run,
            )
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        err_report = {
            "issue": 2678,
            "workflow": args.workflow,
            "branch": args.branch,
            "main_sha": args.main_sha.strip(),
            "status": "error",
            "synced": False,
            "reason": "monitor-execution-error",
            "recommended_action": "inspect_monitor_error",
            "recommended_command": [],
            "retry_run_id": None,
            "runs_inspected": 0,
            "active_runs_count": 0,
            "cancelled_runs_count": 0,
            "failed_runs_count": 0,
            "latest_run": None,
            "latest_main_run": None,
            "contract_audit": contract_audit,
            "warnings": [],
            "errors": [str(exc)],
            "dry_run": dry_run,
        }
        emit_annotations_and_outputs(
            err_report,
            json_out=args.json_out,
            markdown_out=args.markdown_out,
            github_output=args.github_output,
        )
        return 1

    emit_annotations_and_outputs(
        report,
        json_out=args.json_out,
        markdown_out=args.markdown_out,
        github_output=args.github_output,
    )

    if not contract_audit["contracts_ok"]:
        return 1
    if args.require_synced and not report["synced"]:
        return 1
    if report["status"] in {"concurrency_cancelled", "needs_manual_escalation", "error"} and not dry_run:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
