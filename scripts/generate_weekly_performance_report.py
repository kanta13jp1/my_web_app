#!/usr/bin/env python3
"""7-day user performance aggregator, PII anonymizer, LLM insight, and safe HTML reporter."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import date, timedelta
import hashlib
import html
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Callable
import urllib.error
import urllib.parse
import urllib.request


EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
PHONE_RE = re.compile(r"(?<!\d)(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)\d{3,4}[-.\s]?\d{3,4}(?!\d)")
JWT_RE = re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{6,}\b")
BEARER_RE = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{6,}")
KNOWN_KEY_RE = re.compile(
    r"\b(?:sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{12,}|AIza[0-9A-Za-z_-]{12,}|re_[A-Za-z0-9_]{8,}|xox[baprs]-[A-Za-z0-9-]{8,})\b"
)
ASSIGN_CRED_RE = re.compile(
    r"(?i)\b(?:api[_-]?key|secret|token|password|passwd|credential)\s*[:=]\s*['\"]?[^\s'\";,}{]{6,}"
)
LONG_ACCOUNT_RE = re.compile(r"(?<!\d)(?:\d[ -]?){12,19}(?!\d)")
SCRIPT_TAG_RE = re.compile(r"(?is)<\s*/?\s*script\b[^>]*>")

SENSITIVE_KEYS = frozenset(
    {
        "email",
        "user_email",
        "phone",
        "phone_number",
        "full_name",
        "display_name",
        "ip_address",
        "authorization",
        "access_token",
        "refresh_token",
    }
)


@dataclass(frozen=True)
class WeeklyMetricsSummary:
    period_start: str
    period_end: str
    prior_start: str
    prior_end: str
    total_events: int
    active_days: int
    tasks_completed: int
    prior_tasks_completed: int
    tasks_delta_pct: float
    focus_minutes: int
    prior_focus_minutes: int
    focus_delta_pct: float
    error_count: int
    error_rate: float


@dataclass(frozen=True)
class AnomalyFinding:
    code: str
    severity: str
    title: str
    detail: str


def _sanitize_url_for_log(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or ""
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"
    scheme = parsed.scheme or "https"
    return f"{scheme}://{host}{parsed.path}"


def anonymize_user_id(raw_user_id: str, *, salt: str = "weekly-perf-v1") -> str:
    digest = hashlib.sha256(f"{salt}:{raw_user_id.strip()}".encode("utf-8")).hexdigest()
    return f"usr_{digest[:12]}"


def redact_pii(text: str) -> str:
    redacted = EMAIL_RE.sub("[REDACTED_EMAIL]", text)
    redacted = JWT_RE.sub("[REDACTED_JWT]", redacted)
    redacted = BEARER_RE.sub("[REDACTED_TOKEN]", redacted)
    redacted = KNOWN_KEY_RE.sub("[REDACTED_TOKEN]", redacted)
    redacted = ASSIGN_CRED_RE.sub("[REDACTED_CREDENTIAL]", redacted)
    redacted = PHONE_RE.sub("[REDACTED_PHONE]", redacted)
    redacted = LONG_ACCOUNT_RE.sub("[REDACTED_NUMBER]", redacted)
    return redacted


def sanitize_record(value: Any, *, raw_user_id: str = "") -> Any:
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for key, item in value.items():
            key_lower = str(key).strip().lower()
            if key_lower in SENSITIVE_KEYS:
                cleaned[str(key)] = "[REDACTED_PII]"
            elif key_lower in {"user_id", "uid"} and isinstance(item, str):
                cleaned[str(key)] = anonymize_user_id(item)
            else:
                cleaned[str(key)] = sanitize_record(item, raw_user_id=raw_user_id)
        return cleaned
    if isinstance(value, list):
        return [sanitize_record(elem, raw_user_id=raw_user_id) for elem in value]
    if isinstance(value, str):
        masked = redact_pii(value)
        if raw_user_id and raw_user_id in masked:
            masked = masked.replace(raw_user_id, anonymize_user_id(raw_user_id))
        return masked
    return value


def _parse_iso_date(raw: object) -> date | None:
    if not isinstance(raw, str) or len(raw.strip()) < 10:
        return None
    try:
        return date.fromisoformat(raw.strip()[:10])
    except ValueError:
        return None


def _pct_delta(current: int, previous: int) -> float:
    if previous <= 0:
        return 100.0 if current > 0 else 0.0
    return round(((current - previous) / previous) * 100.0, 1)


def aggregate_weekly_metrics(
    events: list[dict[str, Any]],
    *,
    period_end: date,
) -> tuple[WeeklyMetricsSummary, list[dict[str, Any]]]:
    period_start = period_end - timedelta(days=6)
    prior_end = period_start - timedelta(days=1)
    prior_start = prior_end - timedelta(days=6)

    current_days: set[date] = set()
    total_events = 0
    tasks_completed = 0
    prior_tasks_completed = 0
    focus_minutes = 0
    prior_focus_minutes = 0
    error_count = 0
    sanitized_notes: list[dict[str, Any]] = []

    for row in events:
        event_day = _parse_iso_date(row.get("occurred_on") or row.get("created_at"))
        if event_day is None:
            continue
        raw_uid = str(row.get("user_id") or "")
        tasks_val = max(0, int(row.get("tasks_completed") or 0))
        focus_val = max(0, int(row.get("focus_minutes") or 0))
        err_val = max(0, int(row.get("error_count") or 0))

        if period_start <= event_day <= period_end:
            current_days.add(event_day)
            total_events += 1
            tasks_completed += tasks_val
            focus_minutes += focus_val
            error_count += err_val
            note = row.get("note")
            if isinstance(note, str) and note.strip():
                sanitized_notes.append(
                    {
                        "day": event_day.isoformat(),
                        "note": sanitize_record(note, raw_user_id=raw_uid),
                    }
                )
        elif prior_start <= event_day <= prior_end:
            prior_tasks_completed += tasks_val
            prior_focus_minutes += focus_val

    error_denom = max(1, total_events + error_count)
    summary = WeeklyMetricsSummary(
        period_start=period_start.isoformat(),
        period_end=period_end.isoformat(),
        prior_start=prior_start.isoformat(),
        prior_end=prior_end.isoformat(),
        total_events=total_events,
        active_days=len(current_days),
        tasks_completed=tasks_completed,
        prior_tasks_completed=prior_tasks_completed,
        tasks_delta_pct=_pct_delta(tasks_completed, prior_tasks_completed),
        focus_minutes=focus_minutes,
        prior_focus_minutes=prior_focus_minutes,
        focus_delta_pct=_pct_delta(focus_minutes, prior_focus_minutes),
        error_count=error_count,
        error_rate=round(error_count / error_denom, 3),
    )
    return summary, sanitized_notes


def detect_anomalies(summary: WeeklyMetricsSummary) -> list[AnomalyFinding]:
    anomalies: list[AnomalyFinding] = []
    if summary.prior_tasks_completed > 0 and summary.tasks_delta_pct <= -30.0:
        anomalies.append(
            AnomalyFinding(
                code="task_completion_drop",
                severity="high",
                title="完了タスク数の大幅減少",
                detail=(
                    f"前週比 {summary.tasks_delta_pct:+.1f}% "
                    f"({summary.prior_tasks_completed}件 -> {summary.tasks_completed}件)"
                ),
            )
        )
    if summary.prior_focus_minutes > 0 and summary.focus_delta_pct <= -30.0:
        anomalies.append(
            AnomalyFinding(
                code="focus_time_drop",
                severity="medium",
                title="集中作業時間の低下",
                detail=(
                    f"前週比 {summary.focus_delta_pct:+.1f}% "
                    f"({summary.prior_focus_minutes}分 -> {summary.focus_minutes}分)"
                ),
            )
        )
    if summary.prior_tasks_completed >= 3 and summary.tasks_delta_pct >= 50.0:
        anomalies.append(
            AnomalyFinding(
                code="task_completion_surge",
                severity="info",
                title="完了タスク数の急増",
                detail=(
                    f"前週比 {summary.tasks_delta_pct:+.1f}% "
                    f"({summary.prior_tasks_completed}件 -> {summary.tasks_completed}件)"
                ),
            )
        )
    if summary.error_count >= 5 or summary.error_rate >= 0.2:
        anomalies.append(
            AnomalyFinding(
                code="error_spike",
                severity="high",
                title="エラー発生率の上昇",
                detail=(
                    f"エラー {summary.error_count}件 "
                    f"(発生率 {summary.error_rate * 100:.1f}%)"
                ),
            )
        )
    if summary.active_days <= 2:
        anomalies.append(
            AnomalyFinding(
                code="low_active_days",
                severity="medium",
                title="稼働日数の低下",
                detail=f"直近7日間のアクティブ日数が {summary.active_days}日 のみです",
            )
        )
    return anomalies


def build_llm_prompt(
    summary: WeeklyMetricsSummary,
    anomalies: list[AnomalyFinding],
    *,
    pseudonym_id: str,
    sanitized_notes: list[dict[str, Any]] | None = None,
) -> str:
    payload = sanitize_record(
        {
            "pseudonym_id": pseudonym_id,
            "period": f"{summary.period_start} .. {summary.period_end}",
            "metrics": {
                "active_days": summary.active_days,
                "total_events": summary.total_events,
                "tasks_completed": summary.tasks_completed,
                "tasks_delta_pct": summary.tasks_delta_pct,
                "focus_minutes": summary.focus_minutes,
                "focus_delta_pct": summary.focus_delta_pct,
                "error_count": summary.error_count,
                "error_rate": summary.error_rate,
            },
            "anomalies": [
                {"code": a.code, "severity": a.severity, "title": a.title, "detail": a.detail}
                for a in anomalies
            ],
            "notes": sanitized_notes or [],
        }
    )
    prompt = (
        "あなたは個人生産性アナリストです。以下の匿名化済み7日間サマリーを評価し、\n"
        "1) 今週の総括 (成果・継続性)\n"
        "2) 検知された異常値・注意点の原因仮説\n"
        "3) 来週すぐ実行できる改善アクション3件 (数値目標つき)\n"
        "を簡潔な日本語 Markdown で出力してください。個人情報は出力に含めないでください。\n\n"
        f"評価データ:\n{json.dumps(payload, ensure_ascii=False, indent=2)}"
    )
    return redact_pii(prompt)


def synthesize_deterministic_insight(
    summary: WeeklyMetricsSummary,
    anomalies: list[AnomalyFinding],
) -> str:
    lines = [
        f"### 週次総括 ({summary.period_start} 〜 {summary.period_end})",
        (
            f"- 稼働日数: **{summary.active_days} / 7日**, "
            f"完了タスク: **{summary.tasks_completed}件** ({summary.tasks_delta_pct:+.1f}% WoW), "
            f"集中時間: **{summary.focus_minutes}分** ({summary.focus_delta_pct:+.1f}% WoW)"
        ),
        "",
        "### 異常値・注意点",
    ]
    if not anomalies:
        lines.append("- 特記すべき異常値は検知されませんでした。安定したペースを維持しています。")
    else:
        for finding in anomalies:
            lines.append(f"- **[{finding.severity.upper()}] {finding.title}**: {finding.detail}")
    lines.extend(
        [
            "",
            "### 来週の推奨アクション",
            "1. 平日の朝一番に最小タスクを1件完了し、連続稼働日数を維持する。",
            "2. 集中ブロック (25分単位) を1日2回確保して完了タスクの落ち込みを防ぐ。",
            "3. エラー記録が多い作業フローを週初めに15分だけ点検する。",
        ]
    )
    return "\n".join(lines)


def _http_post_json(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    safe_url = _sanitize_url_for_log(url)
    try:
        with opener(req, timeout=20) as resp:
            status = getattr(resp, "status", None)
            if status is None and hasattr(resp, "getcode"):
                status = resp.getcode()
            if status is None or not (200 <= int(status) < 300):
                raise RuntimeError(f"HTTP error {status} on {safe_url}")
            raw_bytes = resp.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"HTTP error {exc.code} on {safe_url}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error on {safe_url}: {exc.reason}") from exc

    text = raw_bytes.decode("utf-8", errors="replace").strip()
    if not text:
        return {}
    try:
        decoded = json.loads(text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Non-JSON response on {safe_url}") from exc
    if not isinstance(decoded, dict):
        raise RuntimeError(f"Unexpected JSON payload type on {safe_url}")
    return decoded


def generate_llm_insight(
    prompt: str,
    summary: WeeklyMetricsSummary,
    anomalies: list[AnomalyFinding],
    *,
    dry_run: bool,
    provider_key: str = "",
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> tuple[str, str]:
    if dry_run or not provider_key.strip():
        return synthesize_deterministic_insight(summary, anomalies), "deterministic_dry_run"

    endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    goog_header = "-".join(("x", "goog", "api", "key"))
    data = _http_post_json(
        endpoint,
        {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.2, "maxOutputTokens": 1024},
        },
        {
            "Content-Type": "application/json",
            goog_header: provider_key.strip(),
        },
        opener=opener,
    )
    candidates = data.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        raise RuntimeError("Gemini response contained no candidates")
    first = candidates[0]
    parts = first.get("content", {}).get("parts", []) if isinstance(first, dict) else []
    texts = [
        str(part.get("text", "")).strip()
        for part in parts
        if isinstance(part, dict) and not part.get("thought") and part.get("text")
    ]
    combined = "\n".join(t for t in texts if t).strip()
    if not combined:
        raise RuntimeError("Gemini response returned empty insight text")
    return redact_pii(combined), "gemini_2_5_flash"


def render_safe_html_report(
    summary: WeeklyMetricsSummary,
    anomalies: list[AnomalyFinding],
    insight_markdown: str,
    *,
    pseudonym_id: str,
    delivery_status: str,
) -> str:
    safe_insight_raw = SCRIPT_TAG_RE.sub("", redact_pii(insight_markdown))
    safe_insight_html = "<br>".join(
        html.escape(line, quote=True) for line in safe_insight_raw.splitlines()
    )

    anomaly_items = []
    if not anomalies:
        anomaly_items.append("<li>特記すべき異常値は検知されませんでした。</li>")
    else:
        for finding in anomalies:
            sev = html.escape(finding.severity.upper(), quote=True)
            title = html.escape(finding.title, quote=True)
            detail = html.escape(finding.detail, quote=True)
            anomaly_items.append(f"<li><strong>[{sev}] {title}</strong>: {detail}</li>")

    return "\n".join(
        [
            "<!DOCTYPE html>",
            '<html lang="ja">',
            "<head>",
            '<meta charset="utf-8">',
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
            f"<title>{html.escape(f'週次パフォーマンスレポート ({summary.period_start}〜{summary.period_end})', quote=True)}</title>",
            "</head>",
            '<body style="margin:0;padding:24px;background:#f8fafc;color:#0f172a;font-family:sans-serif;">',
            '<div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #cbd5e1;border-radius:10px;padding:20px;">',
            f'<h1 style="margin-top:0;color:#0f172a;font-size:20px;">週次パフォーマンスレポート</h1>',
            (
                f'<p style="color:#334155;">期間: {html.escape(summary.period_start, quote=True)} 〜 '
                f'{html.escape(summary.period_end, quote=True)} / '
                f'対象ID: <code>{html.escape(pseudonym_id, quote=True)}</code> / '
                f'状態: <strong>{html.escape(delivery_status, quote=True)}</strong></p>'
            ),
            '<table style="width:100%;border-collapse:collapse;margin:16px 0;">',
            "<tr>",
            f'<td style="padding:8px;border:1px solid #e2e8f0;">稼働日数: <strong>{summary.active_days} / 7日</strong></td>',
            f'<td style="padding:8px;border:1px solid #e2e8f0;">完了タスク: <strong>{summary.tasks_completed}件</strong> ({html.escape(f"{summary.tasks_delta_pct:+.1f}%", quote=True)})</td>',
            "</tr>",
            "<tr>",
            f'<td style="padding:8px;border:1px solid #e2e8f0;">集中時間: <strong>{summary.focus_minutes}分</strong> ({html.escape(f"{summary.focus_delta_pct:+.1f}%", quote=True)})</td>',
            f'<td style="padding:8px;border:1px solid #e2e8f0;">エラー件数: <strong>{summary.error_count}件</strong></td>',
            "</tr>",
            "</table>",
            '<h2 style="font-size:16px;color:#0f172a;">異常値検知</h2>',
            f'<ul>{"".join(anomaly_items)}</ul>',
            '<h2 style="font-size:16px;color:#0f172a;">AI インサイト</h2>',
            f'<div style="background:#f8fafc;padding:12px;border-radius:6px;line-height:1.6;">{safe_insight_html}</div>',
            '<p style="margin-top:16px;font-size:12px;color:#475569;">PII匿名化・HTMLエスケープ適用済みレポート</p>',
            "</div>",
            "</body>",
            "</html>",
        ]
    )


def send_email_resend(
    *,
    provider_key: str,
    sender: str,
    recipient: str,
    subject: str,
    html_body: str,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    if not provider_key.strip() or not sender.strip() or not recipient.strip():
        raise RuntimeError("Email delivery credentials and sender/recipient are required")
    return _http_post_json(
        "https://api.resend.com/emails",
        {
            "from": sender.strip(),
            "to": [recipient.strip()],
            "subject": subject.strip(),
            "html": html_body,
        },
        {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {provider_key.strip()}",
        },
        opener=opener,
    )


def build_default_sample_events(period_end: date) -> list[dict[str, Any]]:
    return [
        {"occurred_on": (period_end - timedelta(days=offset)).isoformat(), "tasks_completed": 4, "focus_minutes": 95, "error_count": 0}
        for offset in range(5)
    ] + [
        {"occurred_on": (period_end - timedelta(days=7 + offset)).isoformat(), "tasks_completed": 5, "focus_minutes": 110, "error_count": 0}
        for offset in range(5)
    ]


def main(
    argv: list[str] | None = None,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> int:
    parser = argparse.ArgumentParser(description="Generate anonymized weekly performance report.")
    parser.add_argument("--input-json", default="", help="Optional path to raw event JSON list")
    parser.add_argument("--period-end", default="", help="Inclusive end date YYYY-MM-DD")
    parser.add_argument("--user-id", default="sample-user-local", help="Raw user identifier (hashed before LLM)")
    parser.add_argument("--dry-run", action="store_true", help="Skip live LLM/email calls (safe default when keys unset)")
    parser.add_argument("--send-email", action="store_true", help="Send rendered HTML email via Resend")
    parser.add_argument("--json-out", default="", help="Optional output path for structured JSON summary")
    parser.add_argument("--html-out", default="", help="Optional output path for HTML report")
    parser.add_argument("--github-output", default="", help="Optional GITHUB_OUTPUT file path")
    args = parser.parse_args(argv)

    period_end = _parse_iso_date(args.period_end) or date.today()
    if args.input_json:
        raw_loaded = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
        events = [row for row in raw_loaded if isinstance(row, dict)] if isinstance(raw_loaded, list) else []
    else:
        events = build_default_sample_events(period_end)

    pseudonym_id = anonymize_user_id(args.user_id)
    summary, sanitized_notes = aggregate_weekly_metrics(events, period_end=period_end)
    anomalies = detect_anomalies(summary)
    prompt = build_llm_prompt(
        summary,
        anomalies,
        pseudonym_id=pseudonym_id,
        sanitized_notes=sanitized_notes,
    )

    gemini_key = os.environ.get("GEMINI_API_KEY", "").strip()
    is_dry_run = bool(args.dry_run) or not gemini_key

    try:
        insight_md, insight_source = generate_llm_insight(
            prompt,
            summary,
            anomalies,
            dry_run=is_dry_run,
            provider_key=gemini_key,
            opener=opener,
        )
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    delivery_status = "dry_run"
    if args.send_email and not args.dry_run:
        resend_key = os.environ.get("RESEND_API_KEY", "").strip()
        sender = os.environ.get("REPORT_FROM_EMAIL", "").strip()
        recipient = os.environ.get("REPORT_TO_EMAIL", "").strip()
        html_preview = render_safe_html_report(
            summary,
            anomalies,
            insight_md,
            pseudonym_id=pseudonym_id,
            delivery_status="sent",
        )
        try:
            send_email_resend(
                provider_key=resend_key,
                sender=sender,
                recipient=recipient,
                subject=f"週次パフォーマンスレポート ({summary.period_start}〜{summary.period_end})",
                html_body=html_preview,
                opener=opener,
            )
            delivery_status = "sent"
        except RuntimeError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 3

    rendered_html = render_safe_html_report(
        summary,
        anomalies,
        insight_md,
        pseudonym_id=pseudonym_id,
        delivery_status=delivery_status,
    )

    result = {
        "pseudonym_id": pseudonym_id,
        "period_start": summary.period_start,
        "period_end": summary.period_end,
        "delivery_status": delivery_status,
        "insight_source": insight_source,
        "pii_redacted": True,
        "metrics_summary": {
            "total_events": summary.total_events,
            "active_days": summary.active_days,
            "tasks_completed": summary.tasks_completed,
            "prior_tasks_completed": summary.prior_tasks_completed,
            "tasks_delta_pct": summary.tasks_delta_pct,
            "focus_minutes": summary.focus_minutes,
            "prior_focus_minutes": summary.prior_focus_minutes,
            "focus_delta_pct": summary.focus_delta_pct,
            "error_count": summary.error_count,
            "error_rate": summary.error_rate,
        },
        "anomalies": [
            {"code": a.code, "severity": a.severity, "title": a.title, "detail": a.detail}
            for a in anomalies
        ],
        "insight_markdown": insight_md,
    }

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    if args.html_out:
        Path(args.html_out).write_text(rendered_html + "\n", encoding="utf-8", newline="\n")
    if args.github_output:
        with Path(args.github_output).open("a", encoding="utf-8", newline="\n") as gh_out:
            gh_out.write(f"delivery_status={delivery_status}\n")
            gh_out.write(f"anomaly_count={len(anomalies)}\n")
            gh_out.write(
                f"report_summary_json={json.dumps(result['metrics_summary'], separators=(',', ':'), ensure_ascii=False)}\n"
            )

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
