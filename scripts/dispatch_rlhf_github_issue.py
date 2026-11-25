#!/usr/bin/env python3
"""Offline/live RLHF bad-output -> GitHub Issue (AI-Feedback) dispatcher (#2659)."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from http import client as http_client
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import ssl
import sys
from typing import Any
from urllib import parse as urllib_parse


DEFAULT_REPO = "kanta13jp1/my_web_app"
DEFAULT_LABELS: tuple[str, ...] = ("AI-Feedback", "rlhf", "automation")
MASK_TOKEN = "***"
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")


@dataclass(frozen=True)
class RlhfIssueDraft:
    feedback_id: str
    title: str
    body: str
    labels: tuple[str, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "feedback_id": self.feedback_id,
            "title": self.title,
            "body": self.body,
            "labels": list(self.labels),
        }


def is_bad_rlhf_rating(rating_status: str) -> bool:
    return rating_status.strip().lower() in {"bad", "problematic"}


def fenced_markdown_block(content: str, language: str = "text") -> str:
    """Wrap untrusted text in a fence longer than any internal backtick run."""
    runs = re.findall(r"`+", content)
    longest = max((len(run) for run in runs), default=0)
    fence = "`" * max(3, longest + 1)
    return f"{fence}{language}\n{content}\n{fence}"


def redact_sensitive_feedback_text(text: str) -> str:
    """Scrub Bearer tokens, API keys, PATs, JWTs, and emails from issue text."""
    if not text:
        return text
    sanitized = re.sub(
        r"\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]+=*",
        lambda m: f"{m.group(1)} {MASK_TOKEN}",
        text,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r"\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b",
        MASK_TOKEN,
        sanitized,
    )
    sanitized = re.sub(
        r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{10,}\b",
        MASK_TOKEN,
        sanitized,
    )
    sanitized = re.sub(r"\bgithub_pat_[A-Za-z0-9_]{10,}\b", MASK_TOKEN, sanitized)
    sanitized = re.sub(
        r"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{12,}\b",
        MASK_TOKEN,
        sanitized,
    )
    sanitized = re.sub(r"\bAIza[0-9A-Za-z_-]{16,}\b", MASK_TOKEN, sanitized)
    sanitized = re.sub(
        r"\bsb_(?:secret|publishable)_[A-Za-z0-9_-]{10,}\b",
        MASK_TOKEN,
        sanitized,
    )
    sanitized = re.sub(
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
        "[masked-email]",
        sanitized,
    )
    return sanitized


def build_rlhf_issue_draft(record: dict[str, Any]) -> RlhfIssueDraft:
    """Build a sanitized GitHub Issue draft with AI-Feedback label from an RLHF row."""
    feedback_id = str(record.get("id") or "(pending-id)").strip()
    action_name = str(record.get("action_name") or "ai_action").strip() or "ai_action"
    model_id = str(record.get("model_id") or "unspecified").strip() or "unspecified"
    rating_status = str(record.get("rating_status") or "bad").strip() or "bad"
    user_id = str(record.get("user_id") or "(anonymous)").strip() or "(anonymous)"
    created_at = str(record.get("created_at") or "").strip()

    safe_prompt = redact_sensitive_feedback_text(str(record.get("prompt_text") or "").strip())
    safe_output = redact_sensitive_feedback_text(str(record.get("ai_output") or "").strip())
    safe_comment = redact_sensitive_feedback_text(str(record.get("user_comment") or "").strip())

    first_line = next(
        (
            line.strip()
            for line in (safe_comment or safe_prompt).splitlines()
            if line.strip()
        ),
        "問題のあるAI出力報告",
    )
    compact = re.sub(r"\s+", " ", first_line)
    summary = f"{compact[:61]}..." if len(compact) > 64 else compact
    title = f"[AI-Feedback] {action_name}: {summary}"

    lines = [
        "## AI Output RLHF Bad Feedback (#2659)",
        "",
        "### Prompt",
        "",
        fenced_markdown_block(safe_prompt) if safe_prompt else "(プロンプト未記録)",
        "",
        "### AI Output",
        "",
        fenced_markdown_block(safe_output) if safe_output else "(出力未記録)",
        "",
        "### User Comment",
        "",
        fenced_markdown_block(safe_comment) if safe_comment else "(コメントなし)",
        "",
        "### Metadata",
        "",
        f"- feedback_id: `{feedback_id}`",
        f"- action_name: `{action_name}`",
        f"- model_id: `{model_id}`",
        f"- rating_status: `{rating_status}`",
        f"- user_id: `{user_id}`",
    ]
    if created_at:
        lines.append(f"- recorded_at: `{created_at}`")
    lines.extend(
        [
            "",
            "---",
            "Auto-created from RLHF bad feedback pipeline (`#2659`).",
        ]
    )
    return RlhfIssueDraft(
        feedback_id=feedback_id,
        title=title,
        body="\n".join(lines),
        labels=DEFAULT_LABELS,
    )


def evaluate_rlhf_queue(records: list[dict[str, Any]]) -> dict[str, Any]:
    """Select pending bad/problematic RLHF items eligible for Issue creation."""
    drafts: list[RlhfIssueDraft] = []
    skipped_good = 0
    skipped_existing = 0

    for item in records:
        rating_status = str(item.get("rating_status") or "")
        if not is_bad_rlhf_rating(rating_status):
            skipped_good += 1
            continue
        if item.get("github_issue_number"):
            skipped_existing += 1
            continue
        dispatch_status = str(item.get("dispatch_status") or "pending").strip().lower()
        if dispatch_status in {"dispatched", "skipped", "not_needed"}:
            skipped_existing += 1
            continue
        drafts.append(build_rlhf_issue_draft(item))

    return {
        "total_records": len(records),
        "eligible_count": len(drafts),
        "skipped_good": skipped_good,
        "skipped_existing": skipped_existing,
        "drafts": [draft.to_dict() for draft in drafts],
    }


def _is_disallowed_ip(ip_obj: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    if isinstance(ip_obj, ipaddress.IPv6Address) and ip_obj.ipv4_mapped is not None:
        return _is_disallowed_ip(ip_obj.ipv4_mapped)
    return (
        not ip_obj.is_global
        or ip_obj.is_private
        or ip_obj.is_loopback
        or ip_obj.is_link_local
        or ip_obj.is_multicast
        or ip_obj.is_reserved
        or ip_obj.is_unspecified
        or (isinstance(ip_obj, ipaddress.IPv4Address) and ip_obj in _CGNAT_NET)
    )


def resolve_and_validate_https_url(raw_url: str) -> tuple[str, str]:
    """Require HTTPS and validate resolved public IPs to block SSRF/DNS rebinding."""
    clean_url = raw_url.strip()
    parsed = urllib_parse.urlsplit(clean_url)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        raise ValueError("Target URL must use https:// with a valid hostname")
    if parsed.username or parsed.password:
        raise ValueError("Target URL must not contain userinfo")
    host = parsed.hostname.lower().rstrip(".")
    if host == "localhost" or host.endswith(".local") or host.endswith(".internal"):
        raise ValueError("Refusing internal/localhost endpoint")
    try:
        ip_literal = ipaddress.ip_address(host)
    except ValueError:
        ip_literal = None
    if ip_literal is not None:
        if _is_disallowed_ip(ip_literal):
            raise ValueError("Refusing disallowed IP literal")
        return clean_url, str(ip_literal)

    try:
        infos = socket.getaddrinfo(host, parsed.port or 443, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise ValueError(f"DNS lookup failed for host: {host}") from exc
    if not infos:
        raise ValueError(f"Empty DNS resolution for host: {host}")
    pinned_ip: str | None = None
    for _, _, _, _, sockaddr in infos:
        addr_ip = ipaddress.ip_address(str(sockaddr[0]).split("%", 1)[0])
        if _is_disallowed_ip(addr_ip):
            raise ValueError(f"Refusing host resolving to non-public IP: {host}")
        if pinned_ip is None:
            pinned_ip = str(addr_ip)
    if pinned_ip is None:
        raise ValueError(f"No public IP resolved for host: {host}")
    return clean_url, pinned_ip


class _PinnedHTTPSConnection(http_client.HTTPSConnection):
    """HTTPSConnection pinned directly to pre-validated IP with strict TLSv1.2+ SNI."""

    def __init__(
        self,
        host: str,
        port: int | None = None,
        *,
        pinned_ip: str,
        sni_hostname: str,
        timeout: float = 10.0,
        context: ssl.SSLContext | None = None,
    ) -> None:
        super().__init__(host, port=port, timeout=timeout, context=context)
        self._pinned_ip = pinned_ip
        self._sni_hostname = sni_hostname

    def connect(self) -> None:
        raw_sock = socket.create_connection(
            (self._pinned_ip, self.port or 443),
            self.timeout,
            self.source_address,
        )
        if self._tunnel_host:
            self.sock = raw_sock
            self._tunnel()
        self.sock = self._context.wrap_socket(
            raw_sock,
            server_hostname=self._sni_hostname,
        )


def post_pinned_json(
    raw_url: str,
    payload: dict[str, Any],
    *,
    headers: dict[str, str],
    timeout: float = 10.0,
) -> tuple[int, dict[str, Any]]:
    """Send POST JSON over IP-pinned TLSv1.2+ HTTPS without following redirects."""
    clean_url, pinned_ip = resolve_and_validate_https_url(raw_url)
    parsed = urllib_parse.urlsplit(clean_url)
    hostname = parsed.hostname or ""
    target = parsed.path or "/"
    if parsed.query:
        target = f"{target}?{parsed.query}"

    ssl_context = ssl.create_default_context()
    ssl_context.minimum_version = ssl.TLSVersion.TLSv1_2
    ssl_context.check_hostname = True
    ssl_context.verify_mode = ssl.CERT_REQUIRED

    req_headers = {
        "Content-Type": "application/json",
        "User-Agent": "jibun-app-rlhf-dispatcher/1.0",
        "Host": parsed.netloc,
        **headers,
    }
    conn = _PinnedHTTPSConnection(
        hostname,
        port=parsed.port or 443,
        pinned_ip=pinned_ip,
        sni_hostname=hostname,
        timeout=timeout,
        context=ssl_context,
    )
    try:
        conn.request(
            "POST",
            target,
            body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers=req_headers,
        )
        resp = conn.getresponse()
        raw_body = resp.read().decode("utf-8", errors="replace")
    finally:
        conn.close()

    if 300 <= resp.status < 400 or resp.status < 200 or resp.status >= 300:
        raise RuntimeError(f"HTTPS request failed for {parsed.netloc} with HTTP {resp.status}")

    decoded = json.loads(raw_body) if raw_body.strip() else {}
    return resp.status, decoded if isinstance(decoded, dict) else {}


def create_github_issue_live(
    repo: str,
    token: str,
    draft: RlhfIssueDraft,
) -> dict[str, Any]:
    """Create a GitHub Issue on owner/repo with AI-Feedback label."""
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError(f"Invalid GitHub repository format: {repo}")
    if not token.strip():
        raise ValueError("GITHUB_TOKEN is required for --live issue creation")

    url = f"https://api.github.com/repos/{repo}/issues"
    _, data = post_pinned_json(
        url,
        {
            "title": draft.title,
            "body": draft.body,
            "labels": list(draft.labels),
        },
        headers={
            "Authorization": f"Bearer {token.strip()}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    return {
        "feedback_id": draft.feedback_id,
        "number": data.get("number"),
        "html_url": data.get("html_url"),
        "labels": list(draft.labels),
    }


def _run_self_test() -> dict[str, Any]:
    sample_records = [
        {
            "id": "self-good",
            "action_name": "summary",
            "prompt_text": "hello",
            "ai_output": "world",
            "rating_status": "good",
            "user_comment": "accurate",
            "dispatch_status": "not_needed",
        },
        {
            "id": "self-bad",
            "user_id": "user-self",
            "action_name": "budget_advisor",
            "model_id": "gemini-2.5-pro",
            "prompt_text": "Test ```fence``` escape",
            "ai_output": ("Bear" + "er") + " stub_val_12345",
            "rating_status": "bad",
            "user_comment": "Wrong calculation",
            "dispatch_status": "pending",
        },
    ]
    evaluation = evaluate_rlhf_queue(sample_records)
    assert evaluation["eligible_count"] == 1
    assert evaluation["skipped_good"] == 1
    draft = evaluation["drafts"][0]
    assert "AI-Feedback" in draft["labels"]
    assert "````text\nTest ```fence``` escape\n````" in draft["body"]
    assert "stub_val_12345" not in draft["body"]
    return {"self_test": "ok", "eligible_count": evaluation["eligible_count"]}


def _write_outputs(
    report: dict[str, Any],
    *,
    json_out: str | None,
    markdown_out: str | None,
    github_output: str | None,
) -> None:
    if json_out:
        Path(json_out).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if markdown_out:
        md_lines = [
            "## RLHF Bad Feedback GitHub Issue Dispatch",
            "",
            f"- Mode: `{report['mode']}`",
            f"- Evaluated at: `{report['evaluated_at']}`",
            f"- Total records: `{report['total_records']}`",
            f"- Eligible bad/problematic: `{report['eligible_count']}`",
            f"- Skipped good: `{report['skipped_good']}`",
            f"- Skipped existing: `{report['skipped_existing']}`",
            f"- Created count: `{len(report['created_issues'])}`",
        ]
        Path(markdown_out).write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as handle:
            handle.write(f"eligible_count={report['eligible_count']}\n")
            handle.write(f"created_count={len(report['created_issues'])}\n")
            handle.write(f"mode={report['mode']}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", help="Optional JSON file containing RLHF feedback rows")
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO),
        help="Target GitHub repository owner/name",
    )
    parser.add_argument("--dry-run", action="store_true", help="Evaluate without creating GitHub issues")
    parser.add_argument("--live", action="store_true", help="Dispatch pending bad feedback rows to GitHub Issues")
    parser.add_argument("--self-test", action="store_true", help="Run built-in offline verification checks")
    parser.add_argument("--json-out", help="Optional output path for JSON summary")
    parser.add_argument("--markdown-out", help="Optional output path for Markdown summary")
    parser.add_argument("--github-output", help="Optional GITHUB_OUTPUT path")
    args = parser.parse_args(argv)

    if args.self_test:
        result = _run_self_test()
        print(json.dumps(result, ensure_ascii=False))
        return 0

    live_mode = bool(args.live and not args.dry_run)
    records: list[dict[str, Any]] = []
    if args.input:
        loaded = json.loads(Path(args.input).read_text(encoding="utf-8"))
        if isinstance(loaded, list):
            records = [item for item in loaded if isinstance(item, dict)]

    evaluation = evaluate_rlhf_queue(records)
    created_issues: list[dict[str, Any]] = []
    if live_mode and evaluation["drafts"]:
        token = (
            os.environ.get("GITHUB_TOKEN")
            or os.environ.get("GH_TOKEN")
            or os.environ.get("GITHUB_PAT")
            or ""
        )
        for draft_dict in evaluation["drafts"]:
            draft = RlhfIssueDraft(
                feedback_id=draft_dict["feedback_id"],
                title=draft_dict["title"],
                body=draft_dict["body"],
                labels=tuple(draft_dict["labels"]),
            )
            created_issues.append(create_github_issue_live(args.repo, token, draft))

    report = {
        "mode": "live" if live_mode else "dry-run",
        "repo": args.repo,
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        **evaluation,
        "created_issues": created_issues,
    }
    _write_outputs(
        report,
        json_out=args.json_out,
        markdown_out=args.markdown_out,
        github_output=args.github_output,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
