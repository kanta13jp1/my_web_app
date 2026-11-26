#!/usr/bin/env python3
"""Unified PR AI-Slop & Security Review Gate (#2789).

Builds on scripts/check_ai_code_antipatterns.py to inspect changed PR files for
AI-generated anti-patterns and security risks, outputting structured Markdown
PR comments and an `ai-slop-warning` / merge-block decision.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable, Sequence

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from check_ai_code_antipatterns import Finding as AntipatternFinding  # noqa: E402
from check_ai_code_antipatterns import scan_file  # noqa: E402

WARNING_LABEL = "ai-slop-warning"

_CREDENTIAL_RE = re.compile(
    "".join([r"(?:sk|ghp|AIza)", r"[_-]?[A-Za-z0-9]{20,}"]),
)
_EVAL_RE = re.compile(r"\b(?:eval|Function)\s*\(")
_INNER_HTML_RE = re.compile(r"dangerouslySetInnerHTML\s*=")
_SQL_INTERP_RE = re.compile(
    r"""(?:SELECT|INSERT|UPDATE|DELETE)\b[^;\n]*\$\{[^}]+\}""",
    re.IGNORECASE,
)

SECURITY_RULES: tuple[tuple[re.Pattern[str], str, str, str], ...] = (
    (
        _CREDENTIAL_RE,
        "hardcoded-credential",
        "critical",
        "Potential hardcoded credential or API token detected",
    ),
    (
        _EVAL_RE,
        "dynamic-code-exec",
        "critical",
        "Dynamic code execution (eval/Function) weakens security boundary",
    ),
    (
        _INNER_HTML_RE,
        "unsafe-html-injection",
        "critical",
        "dangerouslySetInnerHTML risks XSS without explicit sanitization",
    ),
    (
        _SQL_INTERP_RE,
        "sql-string-interpolation",
        "critical",
        "SQL template interpolation risks injection; use parameterized queries",
    ),
)


@dataclass(frozen=True)
class SecurityFinding:
    code: str
    severity: str
    message: str
    path: str
    line: int


@dataclass(frozen=True)
class SlopFindingRecord:
    code: str
    message: str
    path: str
    line: int | None = None


@dataclass(frozen=True)
class SlopReviewReport:
    decision: str
    apply_warning_label: bool
    should_block_merge: bool
    warning_label: str
    optional_llm_status: str
    security_findings: tuple[SecurityFinding, ...]
    antipattern_findings: tuple[SlopFindingRecord, ...]
    markdown: str


def scan_security_risks(path: Path) -> list[SecurityFinding]:
    """Scan a single source file for high-risk security patterns."""
    if not path.exists() or not path.is_file():
        return []
    if path.suffix.lower() not in {".ts", ".tsx", ".js", ".dart", ".py", ".sql"}:
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []

    findings: list[SecurityFinding] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            continue
        for pattern, code, severity, message in SECURITY_RULES:
            if pattern.search(line):
                findings.append(
                    SecurityFinding(
                        code=code,
                        severity=severity,
                        message=message,
                        path=path.as_posix(),
                        line=line_no,
                    )
                )
    return findings


def render_pr_comment_markdown(
    *,
    decision: str,
    apply_warning_label: bool,
    should_block_merge: bool,
    optional_llm_status: str,
    security_findings: Sequence[SecurityFinding],
    antipattern_findings: Sequence[SlopFindingRecord],
) -> str:
    """Render a deterministic Markdown PR review summary."""
    status_badge = {
        "approve": "PASS",
        "warn": "WARN (`ai-slop-warning`)",
        "block": "BLOCK (`ai-slop-warning`)",
    }.get(decision, decision.upper())

    lines = [
        "## AI Slop & Security Review Gate",
        f"- Decision: **{status_badge}**",
        f"- Warning Label (`{WARNING_LABEL}`): `{apply_warning_label}`",
        f"- Merge Blocked: `{should_block_merge}`",
        f"- Optional LLM Audit: `{optional_llm_status}`",
        f"- Security Findings: `{len(security_findings)}`",
        f"- AI-Slop Anti-pattern Findings: `{len(antipattern_findings)}`",
    ]

    if security_findings:
        lines.append("")
        lines.append("### Security Risk Findings")
        for item in security_findings:
            lines.append(
                f"- `[{item.severity}:{item.code}]` "
                f"`{item.path}:{item.line}` — {item.message}"
            )

    if antipattern_findings:
        lines.append("")
        lines.append("### AI-Slop Anti-pattern Findings")
        for item in antipattern_findings:
            loc = f":{item.line}" if item.line is not None else ""
            lines.append(
                f"- `[{item.code}]` `{item.path}{loc}` — {item.message}"
            )

    return "\n".join(lines) + "\n"


def evaluate_pr_files(
    paths: Sequence[Path],
    *,
    block_on_slop_count: int = 2,
    llm_auditor: Callable[[Sequence[Path]], str] | None = None,
    has_llm_key: bool | None = None,
) -> SlopReviewReport:
    """Evaluate PR files for AI-slop anti-patterns and security risks."""
    security_findings: list[SecurityFinding] = []
    antipattern_findings: list[SlopFindingRecord] = []

    for path in paths:
        security_findings.extend(scan_security_risks(path))
        ap_list: list[AntipatternFinding] = scan_file(path)
        for item in ap_list:
            antipattern_findings.append(
                SlopFindingRecord(
                    code=item.code,
                    message=item.message,
                    path=path.as_posix(),
                    line=item.line,
                )
            )

    key_present = (
        bool(os.environ.get("ANTHROPIC_API_KEY", "").strip())
        if has_llm_key is None
        else has_llm_key
    )
    if llm_auditor is not None and key_present:
        try:
            optional_llm_status = llm_auditor(paths)
        except Exception:
            optional_llm_status = "failed_fail_open"
    else:
        optional_llm_status = "skipped_missing_key"

    has_critical_security = any(
        f.severity == "critical" for f in security_findings
    )
    slop_count = len(antipattern_findings)

    if has_critical_security or slop_count >= block_on_slop_count:
        decision = "block"
        apply_warning_label = True
        should_block_merge = True
    elif slop_count > 0 or len(security_findings) > 0:
        decision = "warn"
        apply_warning_label = True
        should_block_merge = False
    else:
        decision = "approve"
        apply_warning_label = False
        should_block_merge = False

    markdown = render_pr_comment_markdown(
        decision=decision,
        apply_warning_label=apply_warning_label,
        should_block_merge=should_block_merge,
        optional_llm_status=optional_llm_status,
        security_findings=security_findings,
        antipattern_findings=antipattern_findings,
    )

    return SlopReviewReport(
        decision=decision,
        apply_warning_label=apply_warning_label,
        should_block_merge=should_block_merge,
        warning_label=WARNING_LABEL,
        optional_llm_status=optional_llm_status,
        security_findings=tuple(security_findings),
        antipattern_findings=tuple(antipattern_findings),
        markdown=markdown,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run unified AI-Slop & Security PR review gate.",
    )
    parser.add_argument("--files", nargs="*", default=[])
    parser.add_argument("--changed-files", default="")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--markdown-out", default="")
    parser.add_argument("--fail-on-block", action="store_true")
    args = parser.parse_args(argv)

    raw_paths = list(args.files)
    if args.changed_files:
        cf_text = Path(args.changed_files).read_text(encoding="utf-8")
        raw_paths.extend(
            line.strip() for line in cf_text.splitlines() if line.strip()
        )

    report = evaluate_pr_files([Path(p) for p in raw_paths])
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(asdict(report), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    if args.markdown_out:
        Path(args.markdown_out).write_text(report.markdown, encoding="utf-8")

    print(report.markdown)
    if args.fail_on_block and report.should_block_merge:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
