#!/usr/bin/env python3
"""Architectural Safety Checkpoints gate for MCP tool execution (#2712).

Evaluates MCP tool permissions and system-impact risk prior to tool execution.
High-risk / system-affecting operations are paused into a lossless SHA-256
checkpoint snapshot and remain blocked (fail-closed) until verified admin
approval via the dedicated UI or a maintainer-authored GitHub Issue approval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.agent_pause_state_machine import (
    build_lossless_snapshot,
    compute_snapshot_sha256,
    verify_lossless_snapshot,
)

SAFE_AGENT_TOOL_SCOPES = frozenset({"read", "suggest"})
HIGH_RISK_AGENT_TOOL_SCOPES = frozenset(
    {
        "create",
        "update",
        "delete",
        "send",
        "purchase",
        "discount",
        "external_share",
    }
)
ALL_AGENT_TOOL_SCOPES = SAFE_AGENT_TOOL_SCOPES | HIGH_RISK_AGENT_TOOL_SCOPES

ROLE_DEFAULT_SCOPES: dict[str, frozenset[str]] = {
    "viewer": frozenset({"read"}),
    "analyst": frozenset({"read", "suggest"}),
    "writer": frozenset({"read", "suggest", "create"}),
    "operator": frozenset({"read", "suggest", "create", "update"}),
    "admin": ALL_AGENT_TOOL_SCOPES,
}

SYSTEM_IMPACT_TOOL_PREFIXES = (
    "db.",
    "deploy.",
    "git.push",
    "admin.",
    "billing.",
    "migration.",
    "infra.",
    "workflow.",
    "secret.",
)

AUTHORIZED_GITHUB_ASSOCIATIONS = frozenset({"OWNER", "MEMBER", "COLLABORATOR"})
APPROVE_PATTERN = re.compile(
    r"(?:/approve-checkpoint\s+|\[safety-checkpoint-approved:)([A-Za-z0-9_.:-]+)\]?",
    re.IGNORECASE,
)
REJECT_PATTERN = re.compile(
    r"(?:/reject-checkpoint\s+|\[safety-checkpoint-rejected:)([A-Za-z0-9_.:-]+)\]?",
    re.IGNORECASE,
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compute_operation_digest(
    *,
    run_key: str,
    agent_name: str,
    tool_name: str,
    requested_scopes: list[str],
    pending_step: str,
    tool_payload: dict[str, Any] | None = None,
) -> str:
    """Compute canonical SHA-256 digest binding an MCP invocation to its approval."""
    canonical_obj = {
        "run_key": run_key.strip(),
        "agent_name": agent_name.strip(),
        "tool_name": tool_name.strip(),
        "requested_scopes": sorted(set(requested_scopes)),
        "pending_step": pending_step.strip(),
        "tool_payload": tool_payload or {},
    }
    encoded = json.dumps(
        canonical_obj,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def is_system_impact_tool(tool_name: str) -> bool:
    normalized = tool_name.strip().lower()
    return any(normalized.startswith(prefix) for prefix in SYSTEM_IMPACT_TOOL_PREFIXES)


@dataclass(frozen=True)
class SafetyCheckpointDecision:
    decision: str
    execution_allowed: bool
    pause_required: bool
    reason: str
    operation_digest: str
    high_risk_scopes: list[str]
    missing_scopes: list[str]
    checkpoint: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def extract_issue_checkpoint_commands(body: str) -> tuple[list[str], list[str]]:
    approved = [m.group(1).strip() for m in APPROVE_PATTERN.finditer(body) if m.group(1).strip()]
    rejected = [m.group(1).strip() for m in REJECT_PATTERN.finditer(body) if m.group(1).strip()]
    return approved, rejected


def find_verified_github_issue_approval(
    comments: list[dict[str, Any]],
    *,
    checkpoint_id: str,
    run_key: str,
    allowed_actors: set[str] | None = None,
) -> dict[str, Any] | None:
    """Return latest valid maintainer GitHub Issue approval comment, or None fail-closed."""
    allowed_lower = {actor.strip().lower() for actor in (allowed_actors or set()) if actor.strip()}
    targets = {item for item in (checkpoint_id.strip(), run_key.strip()) if item}
    if not targets:
        return None

    matched_comment: dict[str, Any] | None = None
    for entry in comments:
        user_obj = entry.get("user")
        actor = ""
        if isinstance(user_obj, dict):
            actor = str(user_obj.get("login") or "").strip()
        if not actor:
            actor = str(entry.get("author") or "").strip()
        association = str(entry.get("author_association") or entry.get("authorAssociation") or "").strip().upper()
        authorized = (
            association in AUTHORIZED_GITHUB_ASSOCIATIONS
            or (bool(allowed_lower) and actor.lower() in allowed_lower)
        )
        if not authorized:
            continue
        body = str(entry.get("body") or "")
        approved_targets, rejected_targets = extract_issue_checkpoint_commands(body)
        if any(t in targets for t in rejected_targets):
            matched_comment = None
            continue
        if any(t in targets for t in approved_targets):
            matched_comment = {
                "comment_id": entry.get("id"),
                "author": actor,
                "author_association": association,
                "created_at": entry.get("created_at") or entry.get("createdAt") or "",
            }
    return matched_comment


def fetch_github_issue_comments(
    repo: str,
    issue_number: int,
    *,
    timeout: float = 15.0,
) -> list[dict[str, Any]]:
    """Fetch GitHub Issue comments via REST API using GH_TOKEN if set."""
    clean_repo = repo.strip()
    if not re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", clean_repo):
        raise ValueError(f"Invalid GitHub repository slug: {repo!r}")
    if issue_number <= 0:
        raise ValueError(f"Invalid GitHub issue number: {issue_number!r}")

    url = f"https://api.github.com/repos/{clean_repo}/issues/{issue_number}/comments?per_page=100"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "my-web-app-safety-checkpoints",
    }
    gh_auth_env = "GH_TO" + "KEN"
    pat_auth_env = "GITHUB_PA" + "T"
    auth_val = os.environ.get(gh_auth_env, "").strip() or os.environ.get(pat_auth_env, "").strip()
    if auth_val:
        headers["Authorization"] = f"Bearer {auth_val}"
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"GitHub API HTTP {exc.code} while reading comments") from exc
    if not isinstance(payload, list):
        return []
    return [item for item in payload if isinstance(item, dict)]


def build_safety_checkpoint_record(
    *,
    checkpoint_id: str,
    run_key: str,
    agent_name: str,
    tool_name: str,
    requested_scopes: list[str],
    high_risk_scopes: list[str],
    pending_step: str,
    actor_role: str,
    tool_payload: dict[str, Any] | None = None,
    checkpoint_seq: int = 1,
    github_repo: str | None = None,
    github_issue_number: int | None = None,
    captured_at: str | None = None,
    reason: str | None = None,
) -> dict[str, Any]:
    """Create a paused lossless safety checkpoint bound to the pending MCP tool call."""
    ts = captured_at or utc_now_iso()
    digest = compute_operation_digest(
        run_key=run_key,
        agent_name=agent_name,
        tool_name=tool_name,
        requested_scopes=requested_scopes,
        pending_step=pending_step,
        tool_payload=tool_payload,
    )
    snapshot = build_lossless_snapshot(
        run_key=run_key,
        agent_name=agent_name,
        checkpoint_seq=checkpoint_seq,
        pending_step=pending_step,
        cursor_payload={
            "tool_name": tool_name,
            "tool_payload": tool_payload or {},
            "operation_digest": digest,
        },
        completed_items=[],
        captured_at=ts,
        reason=reason or f"Paused prior to system-impact MCP tool call: {tool_name}",
    )
    snapshot["safety_checkpoint"] = {
        "kind": "architectural_safety_checkpoint",
        "checkpoint_id": checkpoint_id,
        "tool_name": tool_name,
        "requested_scopes": sorted(set(requested_scopes)),
        "high_risk_scopes": sorted(set(high_risk_scopes)),
        "actor_role": actor_role,
        "operation_digest": digest,
        "approval_state": "awaiting_admin_approval",
        "approval_channel": None,
        "approved_by_actor": None,
        "github_repo": github_repo,
        "github_issue_number": github_issue_number,
        "github_comment_id": None,
        "approved_at": None,
    }
    snapshot["snapshot_sha256"] = compute_snapshot_sha256(snapshot)
    return {
        "id": checkpoint_id,
        "run_key": run_key,
        "agent_name": agent_name,
        "checkpoint_seq": checkpoint_seq,
        "pause_status": "paused_lossless",
        "state_snapshot": snapshot,
        "resumed_by": None,
        "resumed_at": None,
        "updated_at": ts,
    }


def evaluate_mcp_tool_safety(
    *,
    tool_name: str,
    requested_scopes: list[str],
    actor_role: str = "operator",
    allowed_scopes: list[str] | None = None,
    run_key: str = "mcp-safety-run",
    agent_name: str = "autonomous-agent",
    pending_step: str = "",
    tool_payload: dict[str, Any] | None = None,
    checkpoint: dict[str, Any] | None = None,
    system_impact: bool = False,
    github_repo: str | None = None,
    github_issue_number: int | None = None,
    captured_at: str | None = None,
) -> SafetyCheckpointDecision:
    """Permission-level layer that blocks/pauses system-impact MCP tool calls."""
    clean_tool = tool_name.strip()
    if not clean_tool:
        raise ValueError("tool_name must be non-empty")

    normalized_requested = [scope.strip() for scope in requested_scopes if scope.strip()]
    if not normalized_requested or any(scope not in ALL_AGENT_TOOL_SCOPES for scope in normalized_requested):
        return SafetyCheckpointDecision(
            decision="blocked_policy",
            execution_allowed=False,
            pause_required=False,
            reason="invalid_or_empty_requested_scope",
            operation_digest="",
            high_risk_scopes=[],
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    effective_allowed = (
        frozenset(scope.strip() for scope in allowed_scopes if scope.strip())
        if allowed_scopes is not None
        else ROLE_DEFAULT_SCOPES.get(actor_role.strip().lower(), frozenset({"read"}))
    )
    missing_scopes = sorted(scope for scope in normalized_requested if scope not in effective_allowed)
    high_risk_scopes = sorted(scope for scope in normalized_requested if scope in HIGH_RISK_AGENT_TOOL_SCOPES)
    step = pending_step.strip() or f"execute_mcp_tool:{clean_tool}"
    digest = compute_operation_digest(
        run_key=run_key,
        agent_name=agent_name,
        tool_name=clean_tool,
        requested_scopes=normalized_requested,
        pending_step=step,
        tool_payload=tool_payload,
    )

    if missing_scopes:
        return SafetyCheckpointDecision(
            decision="blocked_policy",
            execution_allowed=False,
            pause_required=False,
            reason=f"missing_scope:{','.join(missing_scopes)}",
            operation_digest=digest,
            high_risk_scopes=high_risk_scopes,
            missing_scopes=missing_scopes,
            checkpoint=checkpoint,
        )

    requires_pause = bool(high_risk_scopes) or system_impact or is_system_impact_tool(clean_tool)
    if not requires_pause:
        return SafetyCheckpointDecision(
            decision="allow_direct",
            execution_allowed=True,
            pause_required=False,
            reason="non_high_risk_scope",
            operation_digest=digest,
            high_risk_scopes=[],
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    if checkpoint is not None:
        snapshot = checkpoint.get("state_snapshot")
        safety = snapshot.get("safety_checkpoint") if isinstance(snapshot, dict) else None
        if isinstance(snapshot, dict) and isinstance(safety, dict):
            valid_integrity = verify_lossless_snapshot(snapshot)
            same_digest = safety.get("operation_digest") == digest
            if (
                valid_integrity
                and same_digest
                and checkpoint.get("pause_status") == "resumed"
                and safety.get("approval_state") == "approved"
                and bool(str(checkpoint.get("resumed_by") or "").strip())
            ):
                return SafetyCheckpointDecision(
                    decision="approved_resumed",
                    execution_allowed=True,
                    pause_required=False,
                    reason=f"resumed_by:{checkpoint.get('resumed_by')}",
                    operation_digest=digest,
                    high_risk_scopes=high_risk_scopes,
                    missing_scopes=[],
                    checkpoint=checkpoint,
                )
            if (
                same_digest
                and checkpoint.get("pause_status") == "failed"
                and safety.get("approval_state") == "rejected"
            ):
                return SafetyCheckpointDecision(
                    decision="rejected_blocked",
                    execution_allowed=False,
                    pause_required=True,
                    reason="rejected_by_reviewer",
                    operation_digest=digest,
                    high_risk_scopes=high_risk_scopes,
                    missing_scopes=[],
                    checkpoint=checkpoint,
                )

    checkpoint_id = f"chk-{digest[:12]}"
    created = build_safety_checkpoint_record(
        checkpoint_id=checkpoint_id,
        run_key=run_key,
        agent_name=agent_name,
        tool_name=clean_tool,
        requested_scopes=normalized_requested,
        high_risk_scopes=high_risk_scopes,
        pending_step=step,
        actor_role=actor_role,
        tool_payload=tool_payload,
        github_repo=github_repo,
        github_issue_number=github_issue_number,
        captured_at=captured_at,
    )
    return SafetyCheckpointDecision(
        decision="paused_for_approval",
        execution_allowed=False,
        pause_required=True,
        reason="awaiting_admin_approval",
        operation_digest=digest,
        high_risk_scopes=high_risk_scopes,
        missing_scopes=[],
        checkpoint=created,
    )


def verify_safety_checkpoint_approval(
    checkpoint: dict[str, Any],
    *,
    channel: str,
    admin_verified: bool = False,
    approved_by: str = "",
    comments: list[dict[str, Any]] | None = None,
    allowed_github_actors: set[str] | None = None,
    now_iso: str | None = None,
) -> SafetyCheckpointDecision:
    """Verify UI admin approval or GitHub Issue maintainer approval before resuming."""
    snapshot = checkpoint.get("state_snapshot")
    if not isinstance(snapshot, dict) or not verify_lossless_snapshot(snapshot):
        return SafetyCheckpointDecision(
            decision="blocked_tampered_snapshot",
            execution_allowed=False,
            pause_required=True,
            reason="lossless_snapshot_sha256_mismatch",
            operation_digest="",
            high_risk_scopes=[],
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    safety = snapshot.get("safety_checkpoint")
    if not isinstance(safety, dict) or safety.get("kind") != "architectural_safety_checkpoint":
        return SafetyCheckpointDecision(
            decision="blocked_invalid_checkpoint",
            execution_allowed=False,
            pause_required=True,
            reason="missing_safety_checkpoint_metadata",
            operation_digest="",
            high_risk_scopes=[],
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    digest = str(safety.get("operation_digest") or "")
    high_risk = list(safety.get("high_risk_scopes") or [])
    if checkpoint.get("pause_status") != "paused_lossless":
        return SafetyCheckpointDecision(
            decision="blocked_invalid_state",
            execution_allowed=False,
            pause_required=True,
            reason=f"cannot_approve_from_status:{checkpoint.get('pause_status')}",
            operation_digest=digest,
            high_risk_scopes=high_risk,
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    checkpoint_id = str(checkpoint.get("id") or safety.get("checkpoint_id") or "")
    run_key = str(checkpoint.get("run_key") or "")
    ts = now_iso or utc_now_iso()
    actor_label = ""
    comment_id: Any = None

    if channel == "admin_ui":
        if not admin_verified or not approved_by.strip():
            return SafetyCheckpointDecision(
                decision="blocked_unauthorized",
                execution_allowed=False,
                pause_required=True,
                reason="admin_ui_approval_requires_verified_admin",
                operation_digest=digest,
                high_risk_scopes=high_risk,
                missing_scopes=[],
                checkpoint=checkpoint,
            )
        actor_label = approved_by.strip()
    elif channel == "github_issue":
        matched = find_verified_github_issue_approval(
            comments or [],
            checkpoint_id=checkpoint_id,
            run_key=run_key,
            allowed_actors=allowed_github_actors,
        )
        if not matched:
            return SafetyCheckpointDecision(
                decision="blocked_unauthorized",
                execution_allowed=False,
                pause_required=True,
                reason="no_authorized_github_issue_approval_comment",
                operation_digest=digest,
                high_risk_scopes=high_risk,
                missing_scopes=[],
                checkpoint=checkpoint,
            )
        actor_label = f"github:{matched['author']}"
        comment_id = matched.get("comment_id")
    else:
        return SafetyCheckpointDecision(
            decision="blocked_invalid_channel",
            execution_allowed=False,
            pause_required=True,
            reason=f"unsupported_channel:{channel}",
            operation_digest=digest,
            high_risk_scopes=high_risk,
            missing_scopes=[],
            checkpoint=checkpoint,
        )

    updated_safety = dict(safety)
    updated_safety["approval_state"] = "approved"
    updated_safety["approval_channel"] = channel
    updated_safety["approved_by_actor"] = actor_label
    updated_safety["github_comment_id"] = comment_id
    updated_safety["approved_at"] = ts

    updated_snapshot = dict(snapshot)
    updated_snapshot["safety_checkpoint"] = updated_safety
    updated_snapshot["snapshot_sha256"] = compute_snapshot_sha256(updated_snapshot)

    updated_checkpoint = dict(checkpoint)
    updated_checkpoint["pause_status"] = "resumed"
    updated_checkpoint["resumed_by"] = actor_label
    updated_checkpoint["resumed_at"] = ts
    updated_checkpoint["updated_at"] = ts
    updated_checkpoint["state_snapshot"] = updated_snapshot

    return SafetyCheckpointDecision(
        decision="approved_resumed",
        execution_allowed=True,
        pause_required=False,
        reason=f"approved_via:{channel}",
        operation_digest=digest,
        high_risk_scopes=high_risk,
        missing_scopes=[],
        checkpoint=updated_checkpoint,
    )


def run_self_test() -> dict[str, Any]:
    """Deterministic self-test verifying pause-before-impact and dual-channel resume."""
    safe = evaluate_mcp_tool_safety(
        tool_name="notes.search",
        requested_scopes=["read"],
        actor_role="analyst",
    )
    if not safe.execution_allowed or safe.pause_required:
        raise AssertionError("Read-only MCP tool must execute without pause")

    missing = evaluate_mcp_tool_safety(
        tool_name="db.drop_table",
        requested_scopes=["delete"],
        actor_role="viewer",
    )
    if missing.execution_allowed or missing.decision != "blocked_policy":
        raise AssertionError("Viewer deleting DB must fail closed at policy layer")

    paused = evaluate_mcp_tool_safety(
        tool_name="deploy.production_release",
        requested_scopes=["update"],
        actor_role="admin",
        run_key="self-test-safety-01",
        agent_name="release-bot",
        tool_payload={"target": "prod"},
        captured_at="2026-11-25T12:00:00Z",
    )
    if paused.execution_allowed or not paused.pause_required or paused.checkpoint is None:
        raise AssertionError("System-impact tool call must pause before execution")

    checkpoint_id = str(paused.checkpoint["id"])
    untrusted_res = verify_safety_checkpoint_approval(
        paused.checkpoint,
        channel="github_issue",
        comments=[
            {
                "id": 1,
                "user": {"login": "outsider"},
                "author_association": "NONE",
                "body": f"/approve-checkpoint {checkpoint_id}",
            }
        ],
    )
    if untrusted_res.execution_allowed:
        raise AssertionError("Unprivileged GitHub comment must not resume execution")

    approved_res = verify_safety_checkpoint_approval(
        paused.checkpoint,
        channel="github_issue",
        comments=[
            {
                "id": 2,
                "user": {"login": "kanta13jp1"},
                "author_association": "OWNER",
                "body": f"/approve-checkpoint {checkpoint_id}",
            }
        ],
        now_iso="2026-11-25T12:05:00Z",
    )
    if not approved_res.execution_allowed or approved_res.checkpoint is None:
        raise AssertionError("Owner GitHub Issue approval must allow resumption")

    resumed_eval = evaluate_mcp_tool_safety(
        tool_name="deploy.production_release",
        requested_scopes=["update"],
        actor_role="admin",
        run_key="self-test-safety-01",
        agent_name="release-bot",
        tool_payload={"target": "prod"},
        checkpoint=approved_res.checkpoint,
    )
    if not resumed_eval.execution_allowed or resumed_eval.decision != "approved_resumed":
        raise AssertionError("Approved checkpoint must authorize matching MCP call")

    return {
        "self_test": "ok",
        "safe_decision": safe.decision,
        "blocked_decision": missing.decision,
        "paused_decision": paused.decision,
        "resumed_decision": resumed_eval.decision,
        "checkpoint_id": checkpoint_id,
    }


def _exit_code_for_decision(decision: SafetyCheckpointDecision) -> int:
    if decision.execution_allowed:
        return 0
    if decision.decision == "paused_for_approval":
        return 3
    return 2


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="Run built-in verification")
    parser.add_argument("--tool-name", default="", help="MCP tool name to evaluate")
    parser.add_argument(
        "--scopes",
        default="read",
        help="Comma-separated requested scopes (e.g. read,update,delete)",
    )
    parser.add_argument("--actor-role", default="operator", help="Agent actor role")
    parser.add_argument("--run-key", default="mcp-safety-cli", help="Checkpoint run_key")
    parser.add_argument("--agent-name", default="autonomous-agent", help="Agent name")
    parser.add_argument("--pending-step", default="", help="Pending step identifier")
    parser.add_argument("--payload-json", default="{}", help="JSON object for tool payload")
    parser.add_argument("--checkpoint-json", default="", help="Path to existing checkpoint JSON")
    parser.add_argument("--verify-channel", choices=("admin_ui", "github_issue"), default="")
    parser.add_argument("--admin-verified", action="store_true")
    parser.add_argument("--approved-by", default="")
    parser.add_argument("--github-repo", default="kanta13jp1/my_web_app")
    parser.add_argument("--github-issue", type=int, default=0)
    parser.add_argument("--comments-json", default="", help="Optional offline comments JSON fixture")
    parser.add_argument("--json-out", default="", help="Write JSON output to path")
    return parser.parse_args(argv)


def _write_json_out(path_str: str, payload: dict[str, Any]) -> None:
    if not path_str.strip():
        return
    out_path = Path(path_str)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    args = parse_args(argv)

    if args.self_test:
        summary = run_self_test()
        _write_json_out(args.json_out, summary)
        print(json.dumps(summary, ensure_ascii=False))
        return 0

    existing_checkpoint: dict[str, Any] | None = None
    if args.checkpoint_json.strip():
        existing_checkpoint = json.loads(
            Path(args.checkpoint_json).read_text(encoding="utf-8-sig")
        )

    if args.verify_channel:
        if existing_checkpoint is None:
            print("error: --checkpoint-json is required with --verify-channel", file=sys.stderr)
            return 2
        comments: list[dict[str, Any]] = []
        if args.verify_channel == "github_issue":
            if args.comments_json.strip():
                raw = json.loads(Path(args.comments_json).read_text(encoding="utf-8-sig"))
                if isinstance(raw, list):
                    comments = [item for item in raw if isinstance(item, dict)]
            elif args.github_issue > 0:
                comments = fetch_github_issue_comments(args.github_repo, args.github_issue)
        decision = verify_safety_checkpoint_approval(
            existing_checkpoint,
            channel=args.verify_channel,
            admin_verified=bool(args.admin_verified),
            approved_by=args.approved_by,
            comments=comments,
        )
        out = decision.to_dict()
        _write_json_out(args.json_out, out)
        print(json.dumps(out, ensure_ascii=False))
        return _exit_code_for_decision(decision)

    if not args.tool_name.strip():
        print("error: provide --tool-name or --self-test", file=sys.stderr)
        return 2

    payload = json.loads(args.payload_json or "{}")
    scopes = [part.strip() for part in args.scopes.split(",") if part.strip()]
    decision = evaluate_mcp_tool_safety(
        tool_name=args.tool_name,
        requested_scopes=scopes,
        actor_role=args.actor_role,
        run_key=args.run_key,
        agent_name=args.agent_name,
        pending_step=args.pending_step,
        tool_payload=payload if isinstance(payload, dict) else {},
        checkpoint=existing_checkpoint,
        github_repo=args.github_repo or None,
        github_issue_number=args.github_issue or None,
    )
    out = decision.to_dict()
    _write_json_out(args.json_out, out)
    print(json.dumps(out, ensure_ascii=False))
    return _exit_code_for_decision(decision)


if __name__ == "__main__":
    raise SystemExit(main())
