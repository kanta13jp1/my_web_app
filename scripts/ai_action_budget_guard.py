#!/usr/bin/env python3
"""Per-action AI token/USD budget calculator and monthly cap auto-pause guard (#2609).

Complements scripts/evaluate_quota_thresholds.py (#2612 tool-level quota checks) by
providing granular per-action token-to-USD calculation, monthly ledger rollup,
80% warning notifications, and fail-closed >=100% auto-pause gating for automated runs.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
from typing import Any
from urllib import error as urllib_error
from urllib import parse as urllib_parse
from urllib import request as urllib_request

MODEL_PRICING_PER_1M_USD: dict[str, tuple[float, float]] = {
    "gpt-4o-mini": (0.15, 0.60),
    "gpt-4o": (2.50, 10.00),
    "claude-3-5-haiku": (0.80, 4.00),
    "claude-sonnet-4": (3.00, 15.00),
    "gemini-2.5-flash": (0.15, 0.60),
    "gemini-2.5-pro": (1.25, 10.00),
    "default": (1.00, 4.00),
}


def sanitize_url_for_log(raw_url: str) -> str:
    """Strip query strings and credentials before printing endpoint errors."""
    parsed = urllib_parse.urlsplit(raw_url)
    host = parsed.hostname or ""
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urllib_parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def estimate_action_cost_usd(
    *,
    model_id: str,
    prompt_units: int,
    completion_units: int,
) -> float:
    """Compute estimated USD cost from input/output token counts using model pricing."""
    if isinstance(prompt_units, bool) or isinstance(completion_units, bool):
        raise ValueError("Token counts must be integers, not booleans")
    if prompt_units < 0 or completion_units < 0:
        raise ValueError("Token counts must be non-negative")
    key = model_id.strip().lower()
    in_rate, out_rate = MODEL_PRICING_PER_1M_USD.get(key, MODEL_PRICING_PER_1M_USD["default"])
    cost = (prompt_units / 1_000_000.0) * in_rate + (completion_units / 1_000_000.0) * out_rate
    return round(cost, 6)


@dataclass(frozen=True)
class BudgetEvaluation:
    billing_month: str
    monthly_usd_cap: float
    total_spent_usd: float
    remaining_usd: float
    usage_pct: float
    warning_threshold_pct: float
    hard_stop_pct: float
    warning_80_triggered: bool
    auto_pause_triggered: bool
    pre_paused: bool
    effective_paused: bool
    tier: str
    action_count: int
    exit_code: int
    reason: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def evaluate_monthly_budget(
    *,
    ledger_entries: list[dict[str, Any]],
    billing_month: str,
    monthly_usd_cap: float = 50.0,
    warning_threshold_pct: float = 80.0,
    hard_stop_pct: float = 100.0,
    pre_paused: bool = False,
) -> BudgetEvaluation:
    """Aggregate monthly action spend and compute 80% warning & 100% auto-pause gate."""
    if monthly_usd_cap <= 0:
        raise ValueError("monthly_usd_cap must be positive")
    if warning_threshold_pct <= 0 or hard_stop_pct <= warning_threshold_pct:
        raise ValueError("Invalid warning/hard-stop percentage thresholds")

    spent = 0.0
    matched_count = 0
    for entry in ledger_entries:
        if not isinstance(entry, dict):
            continue
        if str(entry.get("billing_month") or "") != billing_month:
            continue
        matched_count += 1
        raw_usd = entry.get("estimated_usd")
        if isinstance(raw_usd, (int, float)) and not isinstance(raw_usd, bool):
            spent += max(0.0, float(raw_usd))
        else:
            spent += estimate_action_cost_usd(
                model_id=str(entry.get("model_id") or "default"),
                prompt_units=int(entry.get("input_tokens") or 0),
                completion_units=int(entry.get("output_tokens") or 0),
            )

    spent = round(spent, 6)
    usage_pct = round((spent / monthly_usd_cap) * 100.0, 2)
    remaining = round(max(0.0, monthly_usd_cap - spent), 6)

    warning_80 = usage_pct >= warning_threshold_pct
    auto_pause = usage_pct >= hard_stop_pct
    effective_paused = bool(pre_paused) or auto_pause

    if pre_paused and not auto_pause:
        tier = "pre_paused"
        reason = f"{billing_month}: config already paused (spent USD {spent:.4f} / USD {monthly_usd_cap:.2f})"
    elif auto_pause:
        tier = "paused_100"
        reason = (
            f"{billing_month}: usage {usage_pct:.2f}% >= {hard_stop_pct:.0f}% "
            f"(spent USD {spent:.4f} / USD {monthly_usd_cap:.2f}) -> AUTO-PAUSE active"
        )
    elif warning_80:
        tier = "warning_80"
        reason = (
            f"{billing_month}: usage {usage_pct:.2f}% >= {warning_threshold_pct:.0f}% "
            f"(spent USD {spent:.4f} / USD {monthly_usd_cap:.2f}) -> proactive warning"
        )
    else:
        tier = "normal"
        reason = f"{billing_month}: usage {usage_pct:.2f}% < {warning_threshold_pct:.0f}% (within budget)"

    return BudgetEvaluation(
        billing_month=billing_month,
        monthly_usd_cap=round(monthly_usd_cap, 4),
        total_spent_usd=spent,
        remaining_usd=remaining,
        usage_pct=usage_pct,
        warning_threshold_pct=warning_threshold_pct,
        hard_stop_pct=hard_stop_pct,
        warning_80_triggered=warning_80,
        auto_pause_triggered=auto_pause,
        pre_paused=bool(pre_paused),
        effective_paused=effective_paused,
        tier=tier,
        action_count=matched_count,
        exit_code=2 if effective_paused else 0,
        reason=reason,
    )


def build_slack_alert_payload(evaluation: BudgetEvaluation) -> dict[str, Any] | None:
    """Return Slack webhook payload when 80% warning or pause gate is triggered."""
    if not evaluation.warning_80_triggered and not evaluation.effective_paused:
        return None
    label = "AUTO-PAUSE (BLOCKED)" if evaluation.effective_paused else "BUDGET WARNING (80%+)"
    return {
        "text": (
            f"[AI Action Budget {label}] month={evaluation.billing_month} "
            f"spent=USD {evaluation.total_spent_usd:.4f} cap=USD {evaluation.monthly_usd_cap:.2f} "
            f"usage={evaluation.usage_pct:.2f}%"
        ),
    }


def build_github_issue_alert_payload(evaluation: BudgetEvaluation) -> dict[str, Any] | None:
    """Return GitHub Issue notification body when monthly cap auto-pause triggers."""
    if not evaluation.effective_paused:
        return None
    return {
        "title": f"[AI Budget Auto-Pause] {evaluation.billing_month} 上限到達・自動停止",
        "body": (
            f"- 対象月: `{evaluation.billing_month}`\n"
            f"- 累計コスト: `USD {evaluation.total_spent_usd:.4f}` / 月次上限 `USD {evaluation.monthly_usd_cap:.2f}` "
            f"(`{evaluation.usage_pct:.2f}%`)\n"
            f"- 状態: `{evaluation.tier}` (`effective_paused=true`)\n"
            f"- 対応: 予算管理UIまたは管理者レビューにより上限見直し・一時停止解除を行ってください。\n"
        ),
    }


def post_json_notification(
    endpoint_url: str,
    payload: dict[str, Any],
    *,
    bearer_credential: str = "",
) -> int:
    """Send JSON notification to Slack/GitHub endpoint with RuntimeError on HTTP failure."""
    safe_url = sanitize_url_for_log(endpoint_url)
    headers = {"Content-Type": "application/json"}
    if bearer_credential.strip():
        headers["Authorization"] = f"Bearer {bearer_credential.strip()}"
    req = urllib_request.Request(
        endpoint_url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib_request.urlopen(req, timeout=15) as resp:
            status = getattr(resp, "status", 200)
            if status < 200 or status >= 300:
                raise RuntimeError(f"Notification endpoint {safe_url} returned HTTP {status}")
            return int(status)
    except urllib_error.HTTPError as exc:
        raise RuntimeError(f"Notification HTTP error {exc.code} at {safe_url}") from exc
    except urllib_error.URLError as exc:
        raise RuntimeError(f"Notification network error at {safe_url}: {exc.reason}") from exc


def build_default_sample_ledger(billing_month: str) -> list[dict[str, Any]]:
    return [
        {
            "action_name": "daily_report_summary",
            "model_id": "gemini-2.5-flash",
            "input_tokens": 120_000,
            "output_tokens": 24_000,
            "billing_month": billing_month,
        },
        {
            "action_name": "pr_static_review",
            "model_id": "claude-sonnet-4",
            "input_tokens": 80_000,
            "output_tokens": 15_000,
            "billing_month": billing_month,
        },
    ]


def main(argv: list[str] | None = None) -> int:
    current_month = datetime.now(timezone.utc).strftime("%Y-%m")
    parser = argparse.ArgumentParser(description="Check per-action AI USD budget and auto-pause gate (#2609)")
    parser.add_argument("--input", type=Path, help="Optional JSON file containing ledger list")
    parser.add_argument("--month", default=current_month)
    parser.add_argument("--cap-usd", type=float, default=50.0)
    parser.add_argument("--pre-paused", action="store_true")
    parser.add_argument("--dry-run", action="store_true", default=True)
    args = parser.parse_args(argv)

    if args.input:
        data = json.loads(args.input.read_text(encoding="utf-8"))
        entries = data if isinstance(data, list) else data.get("ledger", [])
    else:
        entries = build_default_sample_ledger(args.month)

    evaluation = evaluate_monthly_budget(
        ledger_entries=entries,
        billing_month=args.month,
        monthly_usd_cap=args.cap_usd,
        pre_paused=args.pre_paused,
    )
    output = {
        "evaluation": evaluation.to_dict(),
        "slack_alert": build_slack_alert_payload(evaluation),
        "github_issue_alert": build_github_issue_alert_payload(evaluation),
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return evaluation.exit_code


if __name__ == "__main__":
    sys.exit(main())
