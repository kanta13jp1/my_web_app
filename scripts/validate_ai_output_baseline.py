#!/usr/bin/env python3
"""Deterministic AI output validation & baseline drift detector (#2657).

Evaluates emergent AI outputs against deterministic banned-term, prompt-leak,
and structure rules, measures drift across canonical baseline prompts, and
optionally posts audit summaries via SSRF-pinned HTTPS connections.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import http.client
import ipaddress
import json
from pathlib import Path
import re
import socket
import ssl
import sys
import urllib.parse


DEFAULT_RULE_SET_VERSION = "v1.0"
DEFAULT_DRIFT_THRESHOLD = 0.25

_HARD_BLOCK_PATTERNS: tuple[tuple[str, re.Pattern[str], str], ...] = (
    (
        "system_prompt_leak_marker",
        re.compile(
            r"(?:SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|DEVELOPER_POLICY_OVERRIDE)",
            re.IGNORECASE,
        ),
        "System prompt leak marker detected; output blocked.",
    ),
    (
        "ungrounded_absolute_guarantee",
        re.compile(
            r"(?:100%\s*guaranteed\s*(?:profit|return)|確実に儲かる|元本保証で必ず増える|絶対に副作用はありません|医学的診断を確定します)",
            re.IGNORECASE,
        ),
        "Ungrounded absolute guarantee detected; output blocked.",
    ),
    (
        "credential_leak_marker",
        re.compile(
            r"(?:-----BEGIN\s+(?:RSA\s+|EC\s+|OPENSSH\s+)?PRIVATE\s+KEY-----|\bsk-[A-Za-z0-9]{20,}|\bgh[pousr]_[A-Za-z0-9]{20,}|\bsb_secret_[A-Za-z0-9_]{12,}|\bAIza[0-9A-Za-z\-_]{30,})"
        ),
        "Credential literal detected in output; output blocked.",
    ),
)

_REMEDIABLE_PLACEHOLDER_RE = re.compile(
    r"\b(?:TODO_PLACEHOLDER|FIXME_OUTPUT|LOREM_IPSUM_PLACEHOLDER)\b",
    re.IGNORECASE,
)
_EMAIL_RE = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE)
_JP_PHONE_RE = re.compile(r"0\d{1,4}-\d{1,4}-\d{3,4}")
_CODE_FENCE_RE = re.compile(r"^```(?:json|JSON)?\s*\n([\s\S]*?)\n```$")
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")


@dataclass(frozen=True)
class ValidationViolation:
    code: str
    severity: str
    message: str


@dataclass(frozen=True)
class ValidationResult:
    rule_set_version: str
    decision: str
    format_contract: str
    allowed: bool
    remediated_output: str
    violations: list[ValidationViolation]
    violation_count: int
    drift_score: float


@dataclass(frozen=True)
class BaselineCase:
    case_id: str
    prompt: str
    candidate_output: str
    format_contract: str
    expected_decision: str
    required_headings: tuple[str, ...] = ()
    required_fields: tuple[str, ...] = ()
    banned_terms: tuple[str, ...] = ()
    max_length: int = 4000


DEFAULT_BASELINE_CASES: tuple[BaselineCase, ...] = (
    BaselineCase(
        case_id="wbs-markdown-clean",
        prompt="今月のWBS完了率を結論と根拠に分けてまとめてください。",
        candidate_output="## 結論\n完了率は92%です。\n\n## 根拠\n主要タスク24件中22件が完了しました。",
        format_contract="markdown_sections",
        expected_decision="passed",
        required_headings=("## 結論", "## 根拠"),
    ),
    BaselineCase(
        case_id="json-fenced-remediation",
        prompt="予算分析結果をJSONで返してください。",
        candidate_output='```json\n{"status": "ok", "variance_pct": 3.2}\n```',
        format_contract="json_object",
        expected_decision="remediated",
        required_fields=("status", "variance_pct"),
    ),
    BaselineCase(
        case_id="placeholder-remediation",
        prompt="リリースノート要約を作成してください。",
        candidate_output="## 結論\n確認済み TODO_PLACEHOLDER の更新です。\n\n## 根拠\nCI検証完了。",
        format_contract="markdown_sections",
        expected_decision="remediated",
        required_headings=("## 結論", "## 根拠"),
    ),
    BaselineCase(
        case_id="emergent-guarantee-block",
        prompt="投資戦略のリスク説明をしてください。",
        candidate_output="## 結論\nこの投資手法は確実に儲かるため損失はありません。\n\n## 根拠\n推測です。",
        format_contract="markdown_sections",
        expected_decision="blocked",
        required_headings=("## 結論", "## 根拠"),
    ),
    BaselineCase(
        case_id="concise-summary-truncate",
        prompt="50文字以内で要約してください。",
        candidate_output="あ" * 80,
        format_contract="concise_summary",
        expected_decision="remediated",
        max_length=50,
    ),
)


def mask_sensitive_excerpt(text: str, max_chars: int = 1000) -> str:
    masked = _EMAIL_RE.sub("***", text)
    masked = _JP_PHONE_RE.sub("***", masked).strip()
    if len(masked) <= max_chars:
        return masked
    if max_chars <= 3:
        return masked[:max_chars]
    return f"{masked[: max_chars - 3]}..."


def _compute_drift_score(violations: list[ValidationViolation]) -> float:
    score = 0.0
    for item in violations:
        if item.severity == "block":
            score += 0.5
        elif item.severity == "remediate":
            score += 0.2
        else:
            score += 0.05
    return round(min(1.0, max(0.0, score)), 4)


def validate_output(
    raw_output: str,
    *,
    rule_set_version: str = DEFAULT_RULE_SET_VERSION,
    format_contract: str = "markdown_sections",
    required_headings: tuple[str, ...] = ("## 結論", "## 根拠"),
    required_fields: tuple[str, ...] = (),
    banned_terms: tuple[str, ...] = (),
    max_length: int = 4000,
) -> ValidationResult:
    working = (raw_output or "").strip()
    violations: list[ValidationViolation] = []

    if not working:
        violations.append(
            ValidationViolation(
                code="empty_output",
                severity="block",
                message="Empty AI output blocked.",
            )
        )
        return ValidationResult(
            rule_set_version=rule_set_version,
            decision="blocked",
            format_contract=format_contract,
            allowed=False,
            remediated_output="",
            violations=violations,
            violation_count=1,
            drift_score=_compute_drift_score(violations),
        )

    for code, pattern, message in _HARD_BLOCK_PATTERNS:
        if pattern.search(working):
            violations.append(ValidationViolation(code=code, severity="block", message=message))

    masked = mask_sensitive_excerpt(working, max_chars=max(max_length * 2, 4000))
    if masked != working:
        working = masked
        violations.append(
            ValidationViolation(
                code="compliance_pii_masked",
                severity="remediate",
                message="Contact PII masked deterministically.",
            )
        )

    if _REMEDIABLE_PLACEHOLDER_RE.search(working):
        working = _REMEDIABLE_PLACEHOLDER_RE.sub("[REMOVED]", working).strip()
        violations.append(
            ValidationViolation(
                code="degenerate_placeholder_token",
                severity="remediate",
                message="Placeholder token replaced.",
            )
        )

    for term in banned_terms:
        cleaned_term = term.strip()
        if not cleaned_term:
            continue
        term_re = re.compile(re.escape(cleaned_term), re.IGNORECASE)
        if term_re.search(working):
            working = term_re.sub("[REMOVED]", working).strip()
            violations.append(
                ValidationViolation(
                    code="custom_banned_term_remediated",
                    severity="remediate",
                    message=f"Banned term removed ({cleaned_term[:24]}).",
                )
            )

    if format_contract == "json_object":
        fence_match = _CODE_FENCE_RE.match(working)
        if fence_match:
            working = fence_match.group(1).strip()
            violations.append(
                ValidationViolation(
                    code="json_code_fence_stripped",
                    severity="remediate",
                    message="Stripped markdown code fence around JSON.",
                )
            )
        try:
            parsed = json.loads(working)
            if not isinstance(parsed, dict):
                violations.append(
                    ValidationViolation(
                        code="invalid_json_object_type",
                        severity="block",
                        message="Top-level JSON value must be an object.",
                    )
                )
            else:
                for field in required_fields:
                    val = parsed.get(field)
                    if val is None or (isinstance(val, str) and not val.strip()):
                        violations.append(
                            ValidationViolation(
                                code=f"missing_required_field_{field}",
                                severity="block",
                                message=f"Missing required JSON field: {field}",
                            )
                        )
                working = json.dumps(parsed, ensure_ascii=False, separators=(",", ":"))
        except json.JSONDecodeError:
            violations.append(
                ValidationViolation(
                    code="invalid_json_syntax",
                    severity="block",
                    message="Invalid JSON syntax.",
                )
            )
    elif format_contract == "markdown_sections":
        headings = required_headings or ("## 結論", "## 根拠")
        for heading in headings:
            if heading and heading not in working:
                violations.append(
                    ValidationViolation(
                        code="missing_required_markdown_heading",
                        severity="block",
                        message=f"Missing required heading: {heading}",
                    )
                )
    elif format_contract == "concise_summary":
        limit = max(40, max_length)
        collapsed = re.sub(r"\n{3,}", "\n\n", working).strip()
        if collapsed != working:
            working = collapsed
            violations.append(
                ValidationViolation(
                    code="whitespace_normalized",
                    severity="warning",
                    message="Normalized repeated newlines.",
                )
            )
        if len(working) > limit:
            working = f"{working[: limit - 3].rstrip()}..."
            violations.append(
                ValidationViolation(
                    code="summary_max_length_truncated",
                    severity="remediate",
                    message=f"Truncated summary to <= {limit} chars.",
                )
            )

    has_block = any(v.severity == "block" for v in violations)
    has_remediate = any(v.severity == "remediate" for v in violations)
    if has_block:
        decision = "blocked"
    elif has_remediate or violations:
        decision = "remediated"
    else:
        decision = "passed"

    return ValidationResult(
        rule_set_version=rule_set_version,
        decision=decision,
        format_contract=format_contract,
        allowed=decision != "blocked",
        remediated_output="" if decision == "blocked" else working,
        violations=violations,
        violation_count=len(violations),
        drift_score=_compute_drift_score(violations),
    )


def build_masked_log_entry(
    prompt: str,
    raw_output: str,
    result: ValidationResult,
) -> dict[str, object]:
    return {
        "rule_set_version": result.rule_set_version,
        "decision": result.decision,
        "format_contract": result.format_contract,
        "prompt_excerpt": mask_sensitive_excerpt(prompt, 1000) or "(empty-prompt)",
        "original_output_excerpt": mask_sensitive_excerpt(raw_output, 2000),
        "remediated_output_excerpt": "[BLOCKED]"
        if result.decision == "blocked"
        else mask_sensitive_excerpt(result.remediated_output, 2000),
        "violations": [asdict(v) for v in result.violations],
        "violation_count": result.violation_count,
        "drift_score": result.drift_score,
    }


def evaluate_baseline_suite(
    cases: tuple[BaselineCase, ...] = DEFAULT_BASELINE_CASES,
    *,
    drift_threshold: float = DEFAULT_DRIFT_THRESHOLD,
) -> dict[str, object]:
    results: list[dict[str, object]] = []
    matched = 0
    drift_sum = 0.0

    for case in cases:
        res = validate_output(
            case.candidate_output,
            format_contract=case.format_contract,
            required_headings=case.required_headings or ("## 結論", "## 根拠"),
            required_fields=case.required_fields,
            banned_terms=case.banned_terms,
            max_length=case.max_length,
        )
        is_match = res.decision == case.expected_decision
        if is_match:
            matched += 1
        drift_sum += res.drift_score
        results.append(
            {
                "case_id": case.case_id,
                "expected_decision": case.expected_decision,
                "actual_decision": res.decision,
                "matched": is_match,
                "drift_score": res.drift_score,
                "violation_codes": [v.code for v in res.violations],
                "log_entry": build_masked_log_entry(case.prompt, case.candidate_output, res),
            }
        )

    total = len(cases)
    avg_drift = round(drift_sum / total, 4) if total > 0 else 0.0
    mismatch_rate = round((total - matched) / total, 4) if total > 0 else 0.0
    anomaly_detected = matched != total or mismatch_rate > drift_threshold

    return {
        "rule_set_version": DEFAULT_RULE_SET_VERSION,
        "cases_total": total,
        "cases_matched": matched,
        "mismatch_rate": mismatch_rate,
        "avg_drift_score": avg_drift,
        "drift_threshold": drift_threshold,
        "anomaly_detected": anomaly_detected,
        "status": "anomaly" if anomaly_detected else "ok",
        "results": results,
    }


def _is_disallowed_ip(ip_str: str) -> bool:
    ip = ipaddress.ip_address(ip_str)
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
        or (isinstance(ip, ipaddress.IPv4Address) and ip in _CGNAT_NET)
    )


def _sanitize_url_for_log(raw_url: str) -> str:
    parsed = urllib.parse.urlsplit(raw_url)
    host = parsed.hostname or "unknown"
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme}://{host}{port}{parsed.path}"


def validate_and_resolve_https_url(url: str) -> tuple[urllib.parse.SplitResult, str]:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("Only explicit https URLs with a valid hostname are allowed")
    port = parsed.port or 443
    infos = socket.getaddrinfo(parsed.hostname, port, type=socket.SOCK_STREAM)
    pinned_ip = ""
    for info in infos:
        addr = info[4][0]
        if _is_disallowed_ip(addr):
            raise ValueError(
                f"Blocked outbound HTTPS target resolving to non-public address: {_sanitize_url_for_log(url)}"
            )
        if not pinned_ip:
            pinned_ip = addr
    if not pinned_ip:
        raise ValueError(f"Could not resolve public IP for {_sanitize_url_for_log(url)}")
    return parsed, pinned_ip


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPSConnection connecting to a pinned public IP while verifying TLS SNI/Host."""

    def __init__(
        self,
        *,
        connect_ip: str,
        server_hostname: str,
        port: int,
        timeout: int,
        context: ssl.SSLContext,
    ) -> None:
        super().__init__(
            host=server_hostname,
            port=port,
            timeout=timeout,
            context=context,
        )
        self._connect_ip = connect_ip

    def connect(self) -> None:
        sock = socket.create_connection((self._connect_ip, self.port), self.timeout, self.source_address)
        if self._tunnel_host:
            self.sock = sock
            self._tunnel()
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


def post_json_pinned_https(
    url: str,
    payload: dict[str, object],
    *,
    headers: dict[str, str] | None = None,
    timeout: int = 10,
) -> dict[str, object]:
    parsed, pinned_ip = validate_and_resolve_https_url(url)
    hostname = parsed.hostname or ""
    port = parsed.port or 443
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.check_hostname = True

    req_headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Host": hostname if port == 443 else f"{hostname}:{port}",
    }
    if headers:
        req_headers.update(headers)

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    conn = _PinnedHTTPSConnection(
        connect_ip=pinned_ip,
        server_hostname=hostname,
        port=port,
        timeout=timeout,
        context=ctx,
    )
    try:
        conn.request("POST", path, body=body, headers=req_headers)
        resp = conn.getresponse()
        raw_resp = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise RuntimeError(
                f"Redirect blocked ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(
                f"HTTPS POST failed ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if not raw_resp.strip():
            return {}
        loaded = json.loads(raw_resp)
        return loaded if isinstance(loaded, dict) else {"data": loaded}
    finally:
        conn.close()


def render_markdown_report(report: dict[str, object], *, mode: str) -> str:
    return "\n".join(
        [
            "### AI Output Deterministic Baseline Validation (#2657)",
            f"- Mode: `{mode}`",
            f"- Rule Set: `{report['rule_set_version']}`",
            f"- Matched Cases: `{report['cases_matched']}/{report['cases_total']}`",
            f"- Mismatch Rate: `{report['mismatch_rate']}` (threshold `{report['drift_threshold']}`)",
            f"- Average Drift Score: `{report['avg_drift_score']}`",
            f"- Anomaly Detected: `{report['anomaly_detected']}`",
            "",
        ]
    )


def run_self_test() -> dict[str, object]:
    report = evaluate_baseline_suite()
    if report["anomaly_detected"]:
        raise AssertionError(f"Self-test baseline failed: {report}")
    return {
        "self_test": "passed",
        "cases_matched": report["cases_matched"],
        "cases_total": report["cases_total"],
        "avg_drift_score": report["avg_drift_score"],
    }


def _write_github_output(path: str, report: dict[str, object]) -> None:
    lines = [
        f"status={report['status']}",
        f"cases_matched={report['cases_matched']}",
        f"cases_total={report['cases_total']}",
        f"drift_rate={report['mismatch_rate']}",
        f"avg_drift_score={report['avg_drift_score']}",
        f"anomaly_detected={str(report['anomaly_detected']).lower()}",
    ]
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Deterministic AI output validation and baseline drift check (#2657)."
    )
    parser.add_argument("--dry-run", action="store_true", help="Run without external writes.")
    parser.add_argument("--live", action="store_true", help="Allow outbound audit webhook if URL set.")
    parser.add_argument("--self-test", action="store_true", help="Run offline deterministic self-test.")
    parser.add_argument("--drift-threshold", type=float, default=DEFAULT_DRIFT_THRESHOLD)
    parser.add_argument("--webhook-url", default="", help="Optional HTTPS endpoint for live mode.")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--markdown-out", default="")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args(argv)

    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    mode = "dry-run" if args.dry_run or not args.live else "live"
    report = evaluate_baseline_suite(drift_threshold=args.drift_threshold)
    markdown = render_markdown_report(report, mode=mode)

    if mode == "live" and args.webhook_url.strip():
        post_json_pinned_https(args.webhook_url.strip(), report)

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        Path(args.markdown_out).write_text(markdown, encoding="utf-8")
    if args.github_output:
        _write_github_output(args.github_output, report)

    print(markdown.strip())
    return 1 if report["anomaly_detected"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
