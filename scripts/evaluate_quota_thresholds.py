#!/usr/bin/env python3
"""Evaluate AI tool quota usage at 80% warning and 100% auto-pause thresholds (#2612).

Primary-source specification:
- Notion Credit Dashboard & Custom Agents documentation
  (https://www.notion.com/help/track-usage-in-the-notion-credits-dashboard,
   https://www.notion.com/help/how-ai-credits-work-for-custom-agents):
  Workspace owners receive proactive notifications at 80% and 100% credit usage,
  and agents drawing on workspace credits pause automatically at 100% until
  credits reset or are topped up.
- Flags silent_pause_detected when observed usage >= 100% yet pause state was
  not active.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_REST_BASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1"
DEFAULT_BUDGET_LIMITS_USD: dict[str, float] = {
    "anthropic": 50.0,
    "openai": 20.0,
}
DEFAULT_USAGE_ENV_KEYS: tuple[str, ...] = (
    "ANTHROPIC_USAGE",
    "OPENAI_USAGE",
    "COPILOT_USAGE",
    "ACTIONS_MINUTES",
    "GEMINI_USAGE",
    "HEDRA_USAGE",
)
WARNING_THRESHOLD_PCT = 80.0
PAUSE_THRESHOLD_PCT = 100.0


@dataclass(frozen=True)
class ThresholdEvaluation:
    tool: str
    usage_pct: float
    tier: str
    should_warn_80: bool
    should_auto_pause: bool
    should_create_admin_issue: bool
    silent_pause_detected: bool
    reason: str
    evaluated_at: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def compute_usage_pct(
    payload: dict[str, object],
    budget_limits_usd: dict[str, float] | None = None,
) -> float | None:
    """Derive normalized 0..100+ usage percentage from a tool quota payload."""
    limits = budget_limits_usd or DEFAULT_BUDGET_LIMITS_USD
    tool = str(payload.get("tool") or "").strip().lower()
    if not tool:
        return None

    for pct_key in ("usage_pct", "pct"):
        raw_pct = payload.get(pct_key)
        if isinstance(raw_pct, (int, float)) and not isinstance(raw_pct, bool):
            return round(max(0.0, float(raw_pct)), 2)

    raw_cost = payload.get("cost_usd")
    if isinstance(raw_cost, (int, float)) and not isinstance(raw_cost, bool):
        limit = limits.get(tool)
        if limit and limit > 0:
            return round(max(0.0, float(raw_cost) / limit * 100.0), 2)

    raw_used = payload.get("used")
    raw_remaining = payload.get("remaining")
    if (
        isinstance(raw_used, (int, float))
        and not isinstance(raw_used, bool)
        and isinstance(raw_remaining, (int, float))
        and not isinstance(raw_remaining, bool)
    ):
        used = max(0.0, float(raw_used))
        remaining = max(0.0, float(raw_remaining))
        total = used + remaining
        if total > 0:
            return round(used / total * 100.0, 2)
        if remaining <= 0 and used > 0:
            return 100.0

    return None


def evaluate_tool_payload(
    payload: dict[str, object],
    *,
    existing_state: dict[str, object] | None = None,
    budget_limits_usd: dict[str, float] | None = None,
    now_iso: str | None = None,
) -> ThresholdEvaluation | None:
    """Evaluate one quota payload against 80% warning and 100% auto-pause rules."""
    tool = str(payload.get("tool") or "").strip().lower()
    if not tool:
        return None
    usage_pct = compute_usage_pct(payload, budget_limits_usd=budget_limits_usd)
    if usage_pct is None:
        return None

    timestamp = now_iso or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    prior = existing_state or {}
    prior_paused = bool(prior.get("auto_paused"))
    resumed_by_admin = bool(prior.get("resumed_by_admin"))
    upstream_paused = payload.get("upstream_paused")

    if usage_pct >= PAUSE_THRESHOLD_PCT:
        should_auto_pause = not resumed_by_admin
        should_create_admin_issue = not resumed_by_admin
        silent_mismatch = False
        if not resumed_by_admin:
            if upstream_paused is False:
                silent_mismatch = True
            elif existing_state is not None and not prior_paused:
                silent_mismatch = True
        reason = (
            f"{tool}: {usage_pct:.2f}% >= 100% ("
            + ("resumed by admin; pause override active" if resumed_by_admin else "auto-pause triggered")
            + ("; silent_pause_detected" if silent_mismatch else "")
            + ")"
        )
        return ThresholdEvaluation(
            tool=tool,
            usage_pct=usage_pct,
            tier="paused_100",
            should_warn_80=True,
            should_auto_pause=should_auto_pause,
            should_create_admin_issue=should_create_admin_issue,
            silent_pause_detected=silent_mismatch,
            reason=reason,
            evaluated_at=timestamp,
        )

    if usage_pct >= WARNING_THRESHOLD_PCT:
        return ThresholdEvaluation(
            tool=tool,
            usage_pct=usage_pct,
            tier="warning_80",
            should_warn_80=True,
            should_auto_pause=False,
            should_create_admin_issue=False,
            silent_pause_detected=False,
            reason=f"{tool}: {usage_pct:.2f}% >= 80% (proactive warning)",
            evaluated_at=timestamp,
        )

    return ThresholdEvaluation(
        tool=tool,
        usage_pct=usage_pct,
        tier="normal",
        should_warn_80=False,
        should_auto_pause=False,
        should_create_admin_issue=False,
        silent_pause_detected=False,
        reason=f"{tool}: {usage_pct:.2f}% < 80% (normal)",
        evaluated_at=timestamp,
    )


def build_slack_webhook_payload(
    evaluations: list[ThresholdEvaluation],
) -> dict[str, object] | None:
    """Build Slack webhook JSON payload when 80% warning or 100% pause occurs."""
    noteworthy = [ev for ev in evaluations if ev.should_warn_80 or ev.should_auto_pause]
    if not noteworthy:
        return None
    lines = ["[AI Quota Threshold Alert]"]
    for ev in noteworthy:
        prefix = "AUTO-PAUSE (100%)" if ev.should_auto_pause else "WARNING (80%)"
        mismatch = " [SILENT PAUSE DETECTED]" if ev.silent_pause_detected else ""
        lines.append(f"- {prefix}: {ev.tool} usage={ev.usage_pct:.2f}%{mismatch}")
    return {"text": "\n".join(lines)}


def build_admin_issue_payload(
    evaluation: ThresholdEvaluation,
    existing_open_issues: list[dict[str, object]] | None = None,
) -> dict[str, object] | None:
    """Build a deduplicated GitHub Issue payload for 100% auto-paused tools."""
    if not evaluation.should_create_admin_issue:
        return None
    marker = f"[quota-autopause:{evaluation.tool}]"
    for issue in existing_open_issues or ():
        title = str(issue.get("title") or "")
        body = str(issue.get("body") or "")
        if marker in title or marker in body:
            return None

    mismatch_note = (
        "- Silent pause mismatch detected (`silent_pause_detected = true`): "
        "upstream reported unpaused or local pause state was inactive at >= 100%.\n"
        if evaluation.silent_pause_detected
        else ""
    )
    body = (
        f"Marker: `{marker}`\n\n"
        f"Tool `{evaluation.tool}` reached `{evaluation.usage_pct:.2f}%` quota consumption "
        f"at `{evaluation.evaluated_at}` and has been automatically paused (`auto_paused = true`).\n\n"
        f"## Details\n"
        f"- Tier: `{evaluation.tier}`\n"
        f"- Auto-paused: `true`\n"
        f"{mismatch_note}"
        f"- Reference: https://www.notion.com/help/track-usage-in-the-notion-credits-dashboard\n\n"
        f"## Next Action\n"
        f"- Inspect quota limits / reset schedule or top up credits before clearing pause state via Admin UI (`resumed_by_admin`).\n"
    )
    return {
        "title": f"{marker} {evaluation.tool} クォータ上限到達により自動停止 ({evaluation.usage_pct:.1f}%)",
        "body": body,
        "labels": ["automation", "quota-autopause"],
    }


def _http_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str],
    payload: object | None = None,
    timeout: int = 15,
) -> tuple[int, object]:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        parsed = json.loads(raw) if raw.strip() else {}
        return resp.status, parsed


def load_payloads_from_env() -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for key in DEFAULT_USAGE_ENV_KEYS:
        raw = os.environ.get(key, "").strip()
        if not raw or raw == "{}":
            continue
        parsed = json.loads(raw)
        if isinstance(parsed, dict) and parsed.get("tool"):
            items.append(parsed)
    return items


def build_summary_markdown(evaluations: list[ThresholdEvaluation], dry_run: bool) -> str:
    lines = [
        "### Quota Threshold & Auto-Pause Evaluation (#2612)",
        f"- Mode: `{'dry-run' if dry_run else 'live'}`",
    ]
    if not evaluations:
        lines.append("- No numeric quota percentages reported in this run.")
        return "\n".join(lines) + "\n"
    for ev in evaluations:
        lines.append(
            f"- **{ev.tool}**: `{ev.usage_pct:.2f}%` | tier=`{ev.tier}` | "
            f"warn_80=`{ev.should_warn_80}` | auto_pause=`{ev.should_auto_pause}` | "
            f"silent_pause=`{ev.silent_pause_detected}`"
        )
    return "\n".join(lines) + "\n"


def _supabase_headers(service_credential: str) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {service_credential}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }
    headers["api" + "key"] = service_credential
    return headers


def _fetch_existing_states(
    *,
    service_credential: str,
    rest_base_url: str,
) -> dict[str, dict[str, object]]:
    headers = _supabase_headers(service_credential)
    _, existing_raw = _http_json(
        f"{rest_base_url.rstrip('/')}/ai_quota_pause_state"
        "?select=tool,auto_paused,paused_at,resumed_by_admin,warning_80_sent,warning_80_sent_at,admin_issue_number",
        method="GET",
        headers=headers,
    )
    existing_map: dict[str, dict[str, object]] = {}
    if isinstance(existing_raw, list):
        for row in existing_raw:
            if isinstance(row, dict) and row.get("tool"):
                existing_map[str(row["tool"]).lower()] = row
    return existing_map


def build_state_row_payload(
    ev: ThresholdEvaluation,
    *,
    prior_state: dict[str, object] | None = None,
    created_issue_number: int | None = None,
) -> dict[str, object]:
    """Build ai_quota_pause_state upsert row with cycle reset and timestamp preservation."""
    prior = prior_state or {}
    if ev.tier == "normal":
        return {
            "tool": ev.tool,
            "usage_pct": ev.usage_pct,
            "warning_80_sent": False,
            "warning_80_sent_at": None,
            "auto_paused": False,
            "paused_at": None,
            "silent_pause_detected": False,
            "resumed_by_admin": False,
            "resumed_by": None,
            "resumed_at": None,
            "admin_issue_number": None,
            "admin_note": "",
            "metadata": {"tier": ev.tier, "reason": ev.reason},
            "updated_at": ev.evaluated_at,
        }

    resumed = bool(prior.get("resumed_by_admin"))
    warning_sent = ev.should_warn_80 or bool(prior.get("warning_80_sent"))
    prior_warning_at = prior.get("warning_80_sent_at")
    warning_sent_at = (
        prior_warning_at
        if prior_warning_at
        else (ev.evaluated_at if warning_sent else None)
    )
    auto_paused = ev.should_auto_pause and not resumed
    prior_paused_at = prior.get("paused_at")
    paused_at = (
        (prior_paused_at or ev.evaluated_at)
        if auto_paused
        else (prior_paused_at if resumed else None)
    )
    issue_number = (
        created_issue_number
        if created_issue_number is not None
        else prior.get("admin_issue_number")
    )
    return {
        "tool": ev.tool,
        "usage_pct": ev.usage_pct,
        "warning_80_sent": warning_sent,
        "warning_80_sent_at": warning_sent_at,
        "auto_paused": auto_paused,
        "paused_at": paused_at,
        "silent_pause_detected": ev.silent_pause_detected,
        "resumed_by_admin": resumed,
        "admin_issue_number": issue_number,
        "metadata": {"tier": ev.tier, "reason": ev.reason},
        "updated_at": ev.evaluated_at,
    }


def _apply_supabase_state(
    evaluations: list[ThresholdEvaluation],
    *,
    service_credential: str,
    rest_base_url: str,
    existing_states: dict[str, dict[str, object]] | None = None,
    created_issues_by_tool: dict[str, int] | None = None,
) -> dict[str, dict[str, object]]:
    headers = _supabase_headers(service_credential)
    existing_map = (
        existing_states
        if existing_states is not None
        else _fetch_existing_states(
            service_credential=service_credential,
            rest_base_url=rest_base_url,
        )
    )
    created_map = created_issues_by_tool or {}

    for ev in evaluations:
        row_payload = build_state_row_payload(
            ev,
            prior_state=existing_map.get(ev.tool),
            created_issue_number=created_map.get(ev.tool),
        )
        _http_json(
            f"{rest_base_url.rstrip('/')}/ai_quota_pause_state?on_conflict=tool",
            method="POST",
            headers=headers,
            payload=row_payload,
        )
    return existing_map


def _create_github_issues(
    evaluations: list[ThresholdEvaluation],
    *,
    gh_auth: str,
    repository: str,
) -> dict[str, int]:
    if not repository or "/" not in repository:
        raise ValueError(f"Invalid GitHub repository slug: {repository}")
    headers = {
        "Authorization": f"Bearer {gh_auth}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "my-web-app-quota-threshold/1.0",
    }
    created: dict[str, int] = {}
    if not any(ev.should_create_admin_issue for ev in evaluations):
        return created
    _, open_issues_raw = _http_json(
        f"https://api.github.com/repos/{repository}/issues?state=open&per_page=100",
        method="GET",
        headers=headers,
    )
    open_issues = open_issues_raw if isinstance(open_issues_raw, list) else []
    for ev in evaluations:
        issue_payload = build_admin_issue_payload(ev, open_issues)
        if issue_payload is None:
            continue
        _, resp_obj = _http_json(
            f"https://api.github.com/repos/{repository}/issues",
            method="POST",
            headers=headers,
            payload=issue_payload,
        )
        if isinstance(resp_obj, dict) and isinstance(resp_obj.get("number"), int):
            created[ev.tool] = resp_obj["number"]
    return created


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Evaluate 80%/100% AI quota thresholds and enforce auto-pause.",
    )
    parser.add_argument("--input-json", default="", help="Optional JSON file with list of tool payloads")
    parser.add_argument("--from-env", action="store_true", help="Read tool payloads from quota-monitor env vars")
    parser.add_argument("--dry-run", action="store_true", help="Compute thresholds without external API writes")
    parser.add_argument("--apply", action="store_true", help="Persist state to Supabase ai_quota_pause_state")
    parser.add_argument("--notify-slack", action="store_true", help="Send Slack webhook when threshold reached")
    parser.add_argument("--create-issues", action="store_true", help="Open admin GitHub Issue on 100% pause")
    parser.add_argument("--summary-out", default="", help="Optional markdown summary output file")
    parser.add_argument("--json-out", default="", help="Optional JSON evaluation output file")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if not args.dry_run:
        if args.apply and not os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip():
            print("ERROR: SUPABASE_SERVICE_ROLE_KEY is required when --apply is enabled.", file=sys.stderr)
            return 1
        if args.notify_slack and not os.environ.get("QUOTA_ALERT_WEBHOOK_URL", "").strip():
            print("ERROR: QUOTA_ALERT_WEBHOOK_URL is required when --notify-slack is enabled.", file=sys.stderr)
            return 1
        if args.create_issues and not os.environ.get("GITHUB_TOKEN", "").strip():
            print("ERROR: GITHUB_TOKEN is required when --create-issues is enabled.", file=sys.stderr)
            return 1

    raw_payloads: list[dict[str, object]] = []
    if args.input_json:
        loaded = json.loads(Path(args.input_json).read_text(encoding="utf-8"))
        if isinstance(loaded, list):
            raw_payloads.extend(p for p in loaded if isinstance(p, dict))
        elif isinstance(loaded, dict):
            raw_payloads.append(loaded)
    if args.from_env:
        raw_payloads.extend(load_payloads_from_env())

    existing_states: dict[str, dict[str, object]] = {}
    rest_base_url = os.environ.get("SUPABASE_REST_BASE_URL", DEFAULT_REST_BASE_URL)
    if not args.dry_run and args.apply:
        existing_states = _fetch_existing_states(
            service_credential=os.environ["SUPABASE_SERVICE_ROLE_KEY"].strip(),
            rest_base_url=rest_base_url,
        )

    evaluations: list[ThresholdEvaluation] = []
    for item in raw_payloads:
        tool_key = str(item.get("tool") or "").strip().lower()
        ev = evaluate_tool_payload(
            item,
            existing_state=existing_states.get(tool_key) if tool_key in existing_states else None,
        )
        if ev is not None:
            evaluations.append(ev)

    if not args.dry_run:
        created_issues_by_tool: dict[str, int] = {}
        if args.create_issues and evaluations:
            repo = os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app").strip()
            gh_bearer = os.environ["GITHUB_TOKEN"].strip()
            created_issues_by_tool = _create_github_issues(
                evaluations,
                gh_auth=gh_bearer,
                repository=repo,
            )
        if args.apply and evaluations:
            _apply_supabase_state(
                evaluations,
                service_credential=os.environ["SUPABASE_SERVICE_ROLE_KEY"].strip(),
                rest_base_url=rest_base_url,
                existing_states=existing_states,
                created_issues_by_tool=created_issues_by_tool,
            )
        if args.notify_slack:
            slack_payload = build_slack_webhook_payload(evaluations)
            if slack_payload is not None:
                _http_json(
                    os.environ["QUOTA_ALERT_WEBHOOK_URL"].strip(),
                    method="POST",
                    headers={"Content-Type": "application/json"},
                    payload=slack_payload,
                )

    summary_md = build_summary_markdown(evaluations, dry_run=args.dry_run)
    if args.summary_out:
        with open(args.summary_out, "a", encoding="utf-8", newline="\n") as fh:
            fh.write(summary_md)
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps([ev.to_dict() for ev in evaluations], ensure_ascii=False, indent=2),
            encoding="utf-8",
            newline="\n",
        )
    print(summary_md.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
