#!/usr/bin/env python3
"""Cursor SDK PR security review and CI failure autofix proposal orchestrator (#2693).

Reuses the repository's existing security redaction (`security_review_input`),
scope guards (`ai_review_gate`), SSRF-pinned HTTPS transport
(`validate_supabase_secrets`), and CFE/analyzer diagnostics parser
(`terminal_agent_autofix`) to:
1. Scan PR diffs deterministically for Supabase/RLS/auth, Flutter, and workflow
   security findings and optionally invoke Cursor SDK/API (`CURSOR_API_KEY`) in
   trusted non-PR contexts (falling back cleanly offline when no key is set).
2. Format inline GitHub PR review comment payloads with strict human-approval
   governance (`auto_merge_allowed: false`, never submitting `APPROVE`).
3. Triage failed CI logs (`workflow_run` / `workflow_dispatch`) and emit an
   auditable autofix branch + draft PR proposal requiring human approval.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Callable, Mapping
import urllib.parse

try:
    import ai_review_gate as scope_mod
    import security_review_input as redact_mod
    import terminal_agent_autofix as diag_mod
    import validate_supabase_secrets as net_mod
except ModuleNotFoundError:  # Imported as scripts.cursor_security_review in tests.
    from scripts import ai_review_gate as scope_mod
    from scripts import security_review_input as redact_mod
    from scripts import terminal_agent_autofix as diag_mod
    from scripts import validate_supabase_secrets as net_mod


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_POLICY_PATH = Path("config/cursor_security_review_policy.json")
CURSOR_CRED_ENV = "CURSOR_" + "API_KEY"
DIFF_HEADER_RE = re.compile(r"^diff --git a/(.+?) b/(.+?)$")
HUNK_HEADER_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")


@dataclass(frozen=True)
class SecurityFinding:
    rule_id: str
    domain: str
    severity: str
    blocking: bool
    path: str
    line: int
    cwe: str
    title: str
    recommendation: str
    source: str
    snippet: str


@dataclass(frozen=True)
class AutofixProposal:
    branch_name: str
    base_branch: str
    pr_title: str
    pr_body: str
    draft: bool
    auto_merge_allowed: bool
    human_approval_required: bool
    diagnostic_count: int
    affected_paths: tuple[str, ...]
    root_cause_categories: tuple[str, ...]
    suggested_steps: tuple[str, ...]


def load_policy(policy_path: Path) -> dict[str, Any]:
    if not policy_path.exists():
        raise FileNotFoundError(f"Cursor security policy not found: {policy_path}")
    payload = json.loads(policy_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Cursor security policy must be a JSON object with schema_version == 1")
    for key in ("sdk", "governance", "security_rules"):
        if key not in payload:
            raise ValueError(f"Cursor security policy missing '{key}'")
    return payload


def sanitize_payload(value: Any) -> Any:
    """Recursively redact accidental secrets or bearer strings from JSON/text data."""
    if isinstance(value, str):
        return redact_mod.redact_secrets(value)
    if isinstance(value, list):
        return [sanitize_payload(item) for item in value]
    if isinstance(value, tuple):
        return [sanitize_payload(item) for item in value]
    if isinstance(value, dict):
        return {str(k): sanitize_payload(v) for k, v in value.items()}
    return value


def extract_added_diff_lines(diff_text: str) -> list[tuple[str, int, str]]:
    """Return `(file_path, new_line_number, added_line_content)` from a unified diff."""
    added: list[tuple[str, int, str]] = []
    current_path = ""
    current_line = 0
    in_hunk = False

    for raw in diff_text.splitlines():
        header_match = DIFF_HEADER_RE.match(raw)
        if header_match:
            current_path = scope_mod.normalize_path(header_match.group(2)) if hasattr(scope_mod, "normalize_path") else header_match.group(2)
            current_line = 0
            in_hunk = False
            continue
        if raw.startswith("+++ "):
            candidate = raw[4:].strip()
            if candidate != "/dev/null" and candidate.startswith("b/"):
                current_path = candidate[2:]
            in_hunk = False
            continue
        hunk_match = HUNK_HEADER_RE.match(raw)
        if hunk_match:
            current_line = int(hunk_match.group(1))
            in_hunk = True
            continue
        if not in_hunk or not current_path:
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            added.append((current_path, max(1, current_line), raw[1:]))
            current_line += 1
        elif raw.startswith("-") and not raw.startswith("---"):
            continue
        elif raw.startswith("\\"):
            continue
        else:
            current_line += 1
    return added


def scan_diff_security_findings(
    diff_text: str,
    policy: Mapping[str, Any],
    *,
    allowed_paths: set[str] | None = None,
) -> list[SecurityFinding]:
    """Scan added diff hunks deterministically against policy security rules."""
    raw_rules = policy.get("security_rules", [])
    compiled_rules: list[tuple[dict[str, Any], re.Pattern[str], re.Pattern[str]]] = []
    for entry in raw_rules:
        if not isinstance(entry, dict):
            continue
        compiled_rules.append(
            (
                entry,
                re.compile(str(entry["path_regex"])),
                re.compile(str(entry["line_regex"])),
            )
        )

    findings: list[SecurityFinding] = []
    seen_keys: set[tuple[str, str, int]] = set()
    for path, line_no, content in extract_added_diff_lines(diff_text):
        normalized = path.replace("\\", "/").lstrip("./")
        if allowed_paths is not None and normalized not in allowed_paths:
            continue
        for rule, path_pat, line_pat in compiled_rules:
            if not path_pat.search(normalized):
                continue
            if not line_pat.search(content):
                continue
            rule_id = str(rule["id"])
            dedup_key = (rule_id, normalized, line_no)
            if dedup_key in seen_keys:
                continue
            seen_keys.add(dedup_key)
            findings.append(
                SecurityFinding(
                    rule_id=rule_id,
                    domain=str(rule.get("domain", "security")),
                    severity=str(rule.get("severity", "medium")),
                    blocking=bool(rule.get("blocking", True)),
                    path=normalized,
                    line=line_no,
                    cwe=str(rule.get("cwe", "")),
                    title=str(rule.get("title", rule_id)),
                    recommendation=str(rule.get("recommendation", "")),
                    source="deterministic_policy",
                    snippet=redact_mod.redact_secrets(content.strip())[:160],
                )
            )
    return findings


def normalize_sdk_findings(
    raw_payload: Any,
    *,
    allowed_paths: set[str] | None = None,
) -> list[SecurityFinding]:
    """Normalize findings JSON returned by `@cursor/sdk` / headless Cursor agent."""
    if raw_payload is None:
        return []
    rows = raw_payload.get("findings", []) if isinstance(raw_payload, dict) else raw_payload
    if not isinstance(rows, list):
        return []

    parsed: list[SecurityFinding] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        path = str(row.get("path") or "").replace("\\", "/").lstrip("./")
        if not path:
            continue
        if allowed_paths is not None and path not in allowed_paths:
            continue
        line_val = row.get("line", 1)
        line_no = max(1, int(line_val)) if isinstance(line_val, (int, str)) and str(line_val).isdigit() else 1
        severity = str(row.get("severity", "medium")).lower()
        if severity not in ("critical", "high", "medium", "low"):
            severity = "medium"
        parsed.append(
            SecurityFinding(
                rule_id=str(row.get("rule_id") or row.get("id") or "cursor-sdk-finding"),
                domain=str(row.get("domain") or "cursor-sdk"),
                severity=severity,
                blocking=bool(row.get("blocking", severity in ("critical", "high"))),
                path=path,
                line=line_no,
                cwe=str(row.get("cwe") or ""),
                title=redact_mod.redact_secrets(str(row.get("title") or "Security review finding"))[:160],
                recommendation=redact_mod.redact_secrets(str(row.get("recommendation") or "Review and remediate with human verification."))[:300],
                source="cursor_sdk",
                snippet=redact_mod.redact_secrets(str(row.get("snippet") or ""))[:160],
            )
        )
    return parsed


def merge_findings(*groups: list[SecurityFinding]) -> list[SecurityFinding]:
    merged: list[SecurityFinding] = []
    seen: set[tuple[str, str, int]] = set()
    for group in groups:
        for item in group:
            key = (item.rule_id, item.path, item.line)
            if key in seen:
                continue
            seen.add(key)
            merged.append(item)
    return merged


def call_cursor_sdk_pinned_https(
    endpoint_url: str,
    cursor_cred: str,
    review_prompt: str,
    *,
    allowed_hosts: tuple[str, ...],
    timeout_seconds: int = 60,
) -> dict[str, Any]:
    """Invoke Cursor review HTTPS endpoint using SSRF-pinned IP resolution."""
    pre_parsed = urllib.parse.urlsplit(endpoint_url)
    host = (pre_parsed.hostname or "").lower()
    if pre_parsed.scheme != "https" or not host:
        raise ValueError("Cursor endpoint must be an explicit https URL")
    if allowed_hosts and host not in {item.lower() for item in allowed_hosts}:
        raise ValueError(f"Blocked Cursor endpoint outside allowlist: {host}")
    parsed, pinned_ip = net_mod.validate_and_resolve_https_url(endpoint_url)

    import ssl

    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.check_hostname = True
    port = parsed.port or 443
    path = parsed.path or "/"
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {cursor_cred}",
        "Host": host if port == 443 else f"{host}:{port}",
    }
    body = json.dumps(
        {"mode": "security_review", "input": review_prompt},
        ensure_ascii=False,
    ).encode("utf-8")

    conn = net_mod._PinnedHTTPSConnection(
        connect_ip=pinned_ip,
        server_hostname=host,
        port=port,
        timeout=timeout_seconds,
        context=ctx,
    )
    try:
        conn.request("POST", path, body=body, headers=headers)
        resp = conn.getresponse()
        raw = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise RuntimeError(f"Redirect blocked ({resp.status}) for {host}")
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(f"Cursor SDK HTTP {resp.status}")
        return json.loads(raw) if raw.strip() else {}
    finally:
        conn.close()


def build_pr_inline_review_payload(
    *,
    pr_number: int | None,
    commit_sha: str,
    findings: list[SecurityFinding],
    sdk_mode: str,
    human_approval_required: bool = True,
) -> dict[str, Any]:
    """Build a GitHub PR Review API payload with inline line comments (never auto-APPROVE)."""
    blocking_count = sum(1 for f in findings if f.blocking)
    comments = []
    for item in findings:
        cwe_suffix = f" ({item.cwe})" if item.cwe else ""
        body_lines = [
            f"**[{item.severity.upper()}]{cwe_suffix} {item.title}**",
            f"- Rule: `{item.rule_id}` (`{item.domain}`, source=`{item.source}`)",
            f"- Recommendation: {item.recommendation}",
        ]
        if item.snippet:
            body_lines.append(f"- Observed line: `{item.snippet}`")
        comments.append(
            {
                "path": item.path,
                "line": max(1, item.line),
                "side": "RIGHT",
                "body": redact_mod.redact_secrets("\n".join(body_lines)),
            }
        )

    event_action = "REQUEST_CHANGES" if blocking_count > 0 else "COMMENT"
    summary_body = "\n".join(
        [
            "### Cursor Automated Security Review (#2693)",
            f"- Review Mode: `{sdk_mode}`",
            f"- Findings: `{len(findings)}` (Blocking: `{blocking_count}`)",
            "- Governance: Human review and merge decision remain mandatory (`auto_merge_allowed: false`).",
        ]
    )
    return sanitize_payload(
        {
            "pr_number": pr_number,
            "commit_id": commit_sha or "HEAD",
            "event": event_action,
            "human_approval_required": human_approval_required,
            "auto_merge_allowed": False,
            "body": summary_body,
            "comments": comments,
        }
    )


def classify_ci_failure_causes(ci_log_text: str) -> tuple[list[str], list[str]]:
    """Classify root causes from CI failure logs without exposing credentials."""
    redacted = redact_mod.redact_secrets(ci_log_text)
    categories: list[str] = []
    steps: list[str] = []

    if "flutter analyze" in redacted.lower() or diag_mod.extract_build_diagnostics(redacted):
        categories.append("dart_analyzer_or_cfe_error")
        steps.append("Inspect reported Dart symbol/null-safety diagnostics and add focused unit/widget regression test.")
    if re.search(r"(?i)deno (?:test|lint|fmt)", redacted) or "supabase/functions/" in redacted:
        categories.append("supabase_edge_function_failure")
        steps.append("Run deno fmt/lint/test on affected Edge Function and verify CORS/auth/log-masking guards.")
    if re.search(r"(?i)(?:unittest|FAILED \(|AssertionError)", redacted):
        categories.append("python_automation_test_failure")
        steps.append("Reproduce failing Python unittest locally (`python -B <test_file>`) and update failing fixture/logic.")
    if re.search(r"(?i)(?:USING \(true\)|WITH CHECK \(true\)|rls|security)", redacted):
        categories.append("security_policy_violation")
        steps.append("Resolve security/RLS gate findings and verify via `security_review_input` + gate scripts.")
    if not categories:
        categories.append("general_ci_failure")
        steps.append("Review CI step logs, apply minimal isolated fix on draft branch, and await human review.")
    return categories, steps


def build_autofix_pr_proposal(
    *,
    ci_log_text: str,
    workflow_run_id: str,
    policy: Mapping[str, Any],
    changed_paths: list[str] | None = None,
) -> AutofixProposal:
    """Build a human-reviewed draft autofix branch and PR proposal from failed CI logs."""
    gov = policy.get("governance", {})
    prefix = str(gov.get("autofix_branch_prefix", "autofix/cursor-ci-"))
    allowed_prefixes = tuple(str(p) for p in gov.get("allowed_autofix_prefixes", ("lib/", "test/", "scripts/")))

    redacted_log = redact_mod.redact_secrets(ci_log_text)
    diagnostics = diag_mod.extract_build_diagnostics(redacted_log)
    categories, steps = classify_ci_failure_causes(redacted_log)

    detected_paths: list[str] = []
    for diag in diagnostics:
        normalized = diag.path.replace("\\", "/").lstrip("./")
        if normalized.startswith(allowed_prefixes) and normalized not in detected_paths:
            detected_paths.append(normalized)
    for item in changed_paths or []:
        normalized = item.replace("\\", "/").lstrip("./")
        if normalized.startswith(allowed_prefixes) and normalized not in detected_paths:
            detected_paths.append(normalized)

    safe_run_id = re.sub(r"[^A-Za-z0-9_-]+", "", workflow_run_id or "manual") or "manual"
    slug = re.sub(r"[^a-z0-9-]+", "-", categories[0].replace("_", "-")).strip("-")
    branch_name = f"{prefix}{safe_run_id}-{slug}"[:80]

    body_lines = [
        "## Cursor CI Failure Triage & Autofix Proposal (#2693)",
        f"- Source CI Run ID: `{safe_run_id}`",
        f"- Root Cause Categories: `{', '.join(categories)}`",
        f"- Parsed Compiler/Analyzer Diagnostics: `{len(diagnostics)}`",
        "- Affected Paths: " + (f"`{', '.join(detected_paths)}`" if detected_paths else "`none detected`"),
        "",
        "### Recommended Next Steps (Human Approval Required)",
    ]
    for step in steps:
        body_lines.append(f"- {step}")
    body_lines.extend(
        [
            "",
            "### Governance Guard",
            "- `draft: true`, `auto_merge_allowed: false`, `human_approval_required: true`",
        ]
    )
    return AutofixProposal(
        branch_name=branch_name,
        base_branch="main",
        pr_title=f"fix(ci): Cursor CI失敗診断と修正提案ドラフト (run {safe_run_id})",
        pr_body=redact_mod.redact_secrets("\n".join(body_lines)),
        draft=True,
        auto_merge_allowed=False,
        human_approval_required=True,
        diagnostic_count=len(diagnostics),
        affected_paths=tuple(detected_paths),
        root_cause_categories=tuple(categories),
        suggested_steps=tuple(steps),
    )


def run_security_review_pipeline(
    *,
    diff_text: str,
    changed_paths: list[str],
    policy: Mapping[str, Any],
    environ: Mapping[str, str],
    pr_number: int | None = None,
    commit_sha: str = "",
    workflow_run_id: str = "",
    ci_log_text: str = "",
    precomputed_sdk_payload: Any = None,
    dry_run: bool = True,
    enable_cursor_sdk: bool = False,
    now: datetime | None = None,
    sdk_invoker: Callable[..., dict[str, Any]] = call_cursor_sdk_pinned_https,
) -> dict[str, Any]:
    """Execute diff redaction, policy + optional Cursor SDK review, inline formatting, and CI triage."""
    effective_now = now or datetime.now(timezone.utc)
    normalized_paths = [
        p.replace("\\", "/").lstrip("./")
        for p in changed_paths
        if p.strip()
    ]
    allowed_set = set(normalized_paths) if normalized_paths else None

    redacted_diff, redactions = redact_mod.redact_secrets_with_count(diff_text)
    max_diff = int(policy.get("sdk", {}).get("max_diff_bytes", 120_000))
    diff_truncated = len(redacted_diff.encode("utf-8")) > max_diff
    bounded_diff = redacted_diff[:max_diff]

    deterministic_findings = scan_diff_security_findings(
        bounded_diff,
        policy,
        allowed_paths=allowed_set,
    )

    cursor_cred = environ.get(CURSOR_CRED_ENV, "").strip()
    sdk_cfg = policy.get("sdk", {})
    allowed_hosts = tuple(str(h) for h in sdk_cfg.get("allowed_hosts", ("api.cursor.com",)))
    endpoint_url = str(sdk_cfg.get("endpoint_url", "https://api.cursor.com/v0/agents/review"))

    sdk_findings: list[SecurityFinding] = normalize_sdk_findings(
        precomputed_sdk_payload,
        allowed_paths=allowed_set,
    )
    sdk_status = "offline_deterministic_fallback"
    sdk_error = ""
    if enable_cursor_sdk and not dry_run:
        if not cursor_cred:
            sdk_status = "offline_fallback_missing_cursor_key"
        else:
            try:
                raw_sdk = sdk_invoker(
                    endpoint_url,
                    cursor_cred,
                    bounded_diff,
                    allowed_hosts=allowed_hosts,
                    timeout_seconds=int(sdk_cfg.get("timeout_seconds", 60)),
                )
                sdk_findings = merge_findings(
                    sdk_findings,
                    normalize_sdk_findings(raw_sdk, allowed_paths=allowed_set),
                )
                sdk_status = "cursor_sdk_executed"
            except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
                sdk_status = "cursor_sdk_error_fallback"
                sdk_error = redact_mod.redact_secrets(str(exc))

    all_findings = merge_findings(deterministic_findings, sdk_findings)
    inline_review = build_pr_inline_review_payload(
        pr_number=pr_number,
        commit_sha=commit_sha,
        findings=all_findings,
        sdk_mode=sdk_status,
        human_approval_required=True,
    )

    autofix_proposal: dict[str, Any] | None = None
    if ci_log_text.strip():
        proposal = build_autofix_pr_proposal(
            ci_log_text=ci_log_text,
            workflow_run_id=workflow_run_id,
            policy=policy,
            changed_paths=normalized_paths,
        )
        autofix_proposal = sanitize_payload(asdict(proposal))

    blocking_count = sum(1 for item in all_findings if item.blocking)
    audit_record = sanitize_payload(
        {
            "schema_version": 1,
            "issue": 2693,
            "evaluated_at": effective_now.isoformat(),
            "sdk_package": sdk_cfg.get("package_name", "@cursor/sdk"),
            "sdk_status": sdk_status,
            "sdk_error": sdk_error,
            "dry_run": dry_run,
            "pr_number": pr_number,
            "commit_sha": commit_sha or "HEAD",
            "files_inspected": len(normalized_paths),
            "diff_redactions": redactions,
            "diff_truncated": diff_truncated,
            "finding_count": len(all_findings),
            "blocking_count": blocking_count,
            "human_approval_required": True,
            "auto_merge_allowed": False,
        }
    )
    return sanitize_payload(
        {
            "schema_version": 1,
            "issue": 2693,
            "audit_log": audit_record,
            "findings": [asdict(item) for item in all_findings],
            "inline_review_payload": inline_review,
            "autofix_proposal": autofix_proposal,
        }
    )


def render_markdown(report: Mapping[str, Any]) -> str:
    audit = report["audit_log"]
    lines = [
        "### Cursor Automated Security Review & Triage Report (#2693)",
        f"- SDK Status: `{audit['sdk_status']}` (`{audit['sdk_package']}`, dry_run=`{audit['dry_run']}`)",
        f"- Files Inspected: `{audit['files_inspected']}` | Redactions Applied: `{audit['diff_redactions']}`",
        f"- Findings: `{audit['finding_count']}` (Blocking: `{audit['blocking_count']}`)",
        f"- Human Approval Required: `{audit['human_approval_required']}` | Auto-Merge Allowed: `{audit['auto_merge_allowed']}`",
    ]
    findings = report.get("findings", [])
    if findings:
        lines.append("")
        lines.append("#### Security Findings")
        for item in findings[:15]:
            lines.append(
                f"- `[{item['severity'].upper()}]` `{item['path']}:{item['line']}` "
                f"`{item['rule_id']}` — {item['title']}"
            )
    proposal = report.get("autofix_proposal")
    if isinstance(proposal, dict):
        lines.extend(
            [
                "",
                "#### CI Failure Autofix Draft Proposal",
                f"- Proposed Branch: `{proposal['branch_name']}` (draft=`{proposal['draft']}`, auto_merge=`{proposal['auto_merge_allowed']}`)",
                f"- Root Causes: `{', '.join(proposal['root_cause_categories'])}`",
            ]
        )
    lines.append("")
    return redact_mod.redact_secrets("\n".join(lines))


def write_github_outputs(path: Path, report: Mapping[str, Any]) -> None:
    audit = report["audit_log"]
    lines = [
        f"sdk_status={audit['sdk_status']}",
        f"finding_count={audit['finding_count']}",
        f"blocking_count={audit['blocking_count']}",
        f"human_approval_required={str(audit['human_approval_required']).lower()}",
    ]
    with path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def run_self_test() -> dict[str, Any]:
    """Run deterministic offline self-tests across diff scan, inline formatting, SDK mock, and CI triage."""
    policy = load_policy(ROOT / DEFAULT_POLICY_PATH)
    sample_diff = "\n".join(
        [
            "diff --git a/supabase/migrations/20261125000100_test.sql b/supabase/migrations/20261125000100_test.sql",
            "--- a/supabase/migrations/20261125000100_test.sql",
            "+++ b/supabase/migrations/20261125000100_test.sql",
            "@@ -0,0 +1,2 @@",
            "+CREATE POLICY open_all ON public.items FOR SELECT USING (true);",
            "+-- end",
            "diff --git a/lib/services/api.dart b/lib/services/api.dart",
            "--- a/lib/services/api.dart",
            "+++ b/lib/services/api.dart",
            "@@ -10,0 +11,1 @@",
            "+final endpoint = 'http://insecure.example.com/v1';",
        ]
    )
    sample_ci_log = "error - Undefined name 'brokenWidget' - lib/pages/home.dart:42:5 - undefined_identifier"

    report = run_security_review_pipeline(
        diff_text=sample_diff,
        changed_paths=["supabase/migrations/20261125000100_test.sql", "lib/services/api.dart"],
        policy=policy,
        environ={},
        pr_number=9999,
        commit_sha="0123456789abcdef",
        workflow_run_id="12345",
        ci_log_text=sample_ci_log,
        dry_run=True,
        enable_cursor_sdk=True,
    )
    if report["audit_log"]["finding_count"] != 2 or report["audit_log"]["blocking_count"] != 2:
        raise AssertionError(f"Self-test finding count mismatch: {report['audit_log']}")
    if report["inline_review_payload"]["event"] != "REQUEST_CHANGES":
        raise AssertionError("Self-test inline review event mismatch")
    if not report["autofix_proposal"] or not report["autofix_proposal"]["draft"]:
        raise AssertionError("Self-test autofix draft proposal missing")

    return {
        "self_test": "passed",
        "rules_loaded": len(policy["security_rules"]),
        "findings": report["audit_log"]["finding_count"],
        "inline_comments": len(report["inline_review_payload"]["comments"]),
        "autofix_branch": report["autofix_proposal"]["branch_name"],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--policy", type=Path, default=None)
    parser.add_argument("--diff-file", type=Path, default=None)
    parser.add_argument("--changed-files", type=Path, default=None)
    parser.add_argument("--cursor-findings-file", type=Path, default=None)
    parser.add_argument("--ci-log-file", type=Path, default=None)
    parser.add_argument("--pr-number", type=int, default=None)
    parser.add_argument("--commit-sha", default="")
    parser.add_argument("--workflow-run-id", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--enable-cursor-sdk", action="store_true")
    parser.add_argument("--strict-blocking", action="store_true")
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--review-payload-out", type=Path, default=None)
    parser.add_argument("--autofix-proposal-out", type=Path, default=None)
    parser.add_argument("--markdown-out", type=Path, default=None)
    parser.add_argument("--github-output", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    args = build_parser().parse_args(argv)
    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    root = args.root.resolve()
    policy = load_policy((args.policy or (root / DEFAULT_POLICY_PATH)).resolve())

    diff_text = args.diff_file.read_text(encoding="utf-8", errors="replace") if args.diff_file and args.diff_file.exists() else ""
    changed_paths = (
        [line.strip() for line in args.changed_files.read_text(encoding="utf-8").splitlines() if line.strip()]
        if args.changed_files and args.changed_files.exists()
        else []
    )
    ci_log_text = args.ci_log_file.read_text(encoding="utf-8", errors="replace") if args.ci_log_file and args.ci_log_file.exists() else ""
    precomputed = (
        json.loads(args.cursor_findings_file.read_text(encoding="utf-8"))
        if args.cursor_findings_file and args.cursor_findings_file.exists()
        else None
    )

    dry_run = bool(args.dry_run or not args.live)
    report = run_security_review_pipeline(
        diff_text=diff_text,
        changed_paths=changed_paths,
        policy=policy,
        environ=dict(os.environ),
        pr_number=args.pr_number,
        commit_sha=args.commit_sha,
        workflow_run_id=args.workflow_run_id,
        ci_log_text=ci_log_text,
        precomputed_sdk_payload=precomputed,
        dry_run=dry_run,
        enable_cursor_sdk=args.enable_cursor_sdk,
    )

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.review_payload_out:
        args.review_payload_out.parent.mkdir(parents=True, exist_ok=True)
        args.review_payload_out.write_text(
            json.dumps(report["inline_review_payload"], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.autofix_proposal_out and report["autofix_proposal"] is not None:
        args.autofix_proposal_out.parent.mkdir(parents=True, exist_ok=True)
        args.autofix_proposal_out.write_text(
            json.dumps(report["autofix_proposal"], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(render_markdown(report), encoding="utf-8")
    if args.github_output:
        write_github_outputs(args.github_output, report)

    print(render_markdown(report))
    if args.strict_blocking and report["audit_log"]["blocking_count"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
