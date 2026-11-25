#!/usr/bin/env python3
"""Scheduled external data diff comparator & alert runner (#2740).

Compares incoming external payloads against prior baseline snapshots,
evaluates configurable trigger rules, formats HTML-escaped notification
emails, and supports safe `--dry-run` default before dispatching `--live`
batches to `core-hub`.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import html
import json
import os
from pathlib import Path
import sys
from typing import Any, Callable
import urllib.request


DEFAULT_CORE_HUB_URL = (
    "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub"
)
VALID_OPERATORS = frozenset({
    "any_change",
    "field_changed",
    "gt",
    "lt",
    "pct_change_gte",
    "contains",
})


@dataclass(frozen=True)
class DiffEntry:
    field_path: str
    change_type: str
    previous_value: Any
    current_value: Any
    numeric_delta: float | None = None
    percent_delta: float | None = None


@dataclass(frozen=True)
class TriggerRule:
    rule_id: str
    rule_name: str
    source_key: str
    field_path: str
    operator: str
    threshold_value: str
    severity: str = "warning"
    notify_email: bool = True
    recipient_email: str = ""
    enabled: bool = True


def _flatten(value: Any, prefix: str, depth: int, out: dict[str, Any]) -> None:
    if depth > 4:
        out[prefix] = value
        return
    if isinstance(value, dict):
        if not value and prefix:
            out[prefix] = {}
            return
        for key, item in value.items():
            nxt = f"{prefix}.{key}" if prefix else str(key)
            _flatten(item, nxt, depth + 1, out)
        return
    out[prefix] = value


def compute_structured_diff(
    previous: dict[str, Any],
    current: dict[str, Any],
) -> list[DiffEntry]:
    """Compare previous and current JSON objects into deterministic diffs."""
    prev_map: dict[str, Any] = {}
    curr_map: dict[str, Any] = {}
    _flatten(previous, "", 0, prev_map)
    _flatten(current, "", 0, curr_map)

    all_keys = sorted(set(prev_map) | set(curr_map))
    diffs: list[DiffEntry] = []

    for key in all_keys:
        in_prev = key in prev_map
        in_curr = key in curr_map
        if not in_prev and in_curr:
            diffs.append(
                DiffEntry(
                    field_path=key,
                    change_type="added",
                    previous_value=None,
                    current_value=curr_map[key],
                )
            )
            continue
        if in_prev and not in_curr:
            diffs.append(
                DiffEntry(
                    field_path=key,
                    change_type="removed",
                    previous_value=prev_map[key],
                    current_value=None,
                )
            )
            continue

        prev_val = prev_map[key]
        curr_val = curr_map[key]
        if json.dumps(prev_val, sort_keys=True) != json.dumps(
            curr_val, sort_keys=True
        ):
            num_delta: float | None = None
            pct_delta: float | None = None
            if (
                isinstance(prev_val, (int, float))
                and not isinstance(prev_val, bool)
                and isinstance(curr_val, (int, float))
                and not isinstance(curr_val, bool)
            ):
                num_delta = round(float(curr_val) - float(prev_val), 4)
                if prev_val != 0:
                    pct_delta = round(
                        abs(float(curr_val) - float(prev_val))
                        / abs(float(prev_val))
                        * 100.0,
                        2,
                    )
            diffs.append(
                DiffEntry(
                    field_path=key,
                    change_type="changed",
                    previous_value=prev_val,
                    current_value=curr_val,
                    numeric_delta=num_delta,
                    percent_delta=pct_delta,
                )
            )
    return diffs


def _read_path(payload: dict[str, Any], path: str) -> Any:
    if not path.strip():
        return payload
    cur: Any = payload
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def evaluate_diff_rules(
    rules: list[TriggerRule],
    source_key: str,
    diffs: list[DiffEntry],
    current_payload: dict[str, Any],
) -> list[dict[str, Any]]:
    """Evaluate enabled trigger rules against computed diff entries."""
    if not diffs:
        return []
    diff_map = {entry.field_path: entry for entry in diffs}
    matches: list[dict[str, Any]] = []

    for rule in rules:
        if not rule.enabled or rule.source_key != source_key:
            continue
        if rule.operator not in VALID_OPERATORS:
            continue

        if rule.operator == "any_change":
            matches.append({
                "rule": asdict(rule),
                "matched_fields": [d.field_path for d in diffs[:8]],
                "reason": f"{len(diffs)} field(s) changed in {source_key}",
            })
            continue

        entry = diff_map.get(rule.field_path.strip())
        if entry is None:
            continue
        curr_val = _read_path(current_payload, rule.field_path.strip())

        if rule.operator == "field_changed":
            matches.append({
                "rule": asdict(rule),
                "matched_fields": [entry.field_path],
                "reason": (
                    f"Field {entry.field_path} updated "
                    f"({entry.previous_value} -> {entry.current_value})"
                ),
            })
            continue

        if rule.operator == "contains":
            needle = rule.threshold_value.lower().strip()
            if needle and needle in str(curr_val or "").lower():
                matches.append({
                    "rule": asdict(rule),
                    "matched_fields": [entry.field_path],
                    "reason": (
                        f"Field {entry.field_path} matched "
                        f"'{rule.threshold_value}'"
                    ),
                })
            continue

        try:
            threshold = float(rule.threshold_value)
        except ValueError:
            continue

        if rule.operator == "pct_change_gte":
            if (
                entry.percent_delta is not None
                and entry.percent_delta >= threshold
            ):
                matches.append({
                    "rule": asdict(rule),
                    "matched_fields": [entry.field_path],
                    "reason": (
                        f"{entry.field_path} changed {entry.percent_delta}% "
                        f"(>= {threshold}%)"
                    ),
                })
            continue

        if isinstance(curr_val, (int, float)) and not isinstance(
            curr_val, bool
        ):
            val_num = float(curr_val)
            if rule.operator == "gt" and val_num > threshold:
                matches.append({
                    "rule": asdict(rule),
                    "matched_fields": [entry.field_path],
                    "reason": f"{entry.field_path}={val_num} > {threshold}",
                })
            elif rule.operator == "lt" and val_num < threshold:
                matches.append({
                    "rule": asdict(rule),
                    "matched_fields": [entry.field_path],
                    "reason": f"{entry.field_path}={val_num} < {threshold}",
                })
    return matches


def format_email_alert_payload(
    source_key: str,
    rule: TriggerRule,
    reason: str,
    diffs: list[DiffEntry],
    detected_at: str,
) -> dict[str, str]:
    """Build an escaped HTML + text email template for a triggered alert."""
    sev = rule.severity.upper()
    subject = f"[{sev}] External Diff Alert: {source_key} ({rule.rule_name})"
    rows_html = "".join(
        "<tr>"
        f"<td>{html.escape(d.field_path)}</td>"
        f"<td>{html.escape(d.change_type)}</td>"
        f"<td>{html.escape(str(d.previous_value))}</td>"
        f"<td>{html.escape(str(d.current_value))}</td>"
        "</tr>"
        for d in diffs[:6]
    )
    html_body = (
        "<!DOCTYPE html><html lang='ja'><body>"
        f"<h2>[{html.escape(sev)}] {html.escape(source_key)}</h2>"
        f"<p>Rule: {html.escape(rule.rule_name)}</p>"
        f"<p>Reason: {html.escape(reason)}</p>"
        f"<table><tbody>{rows_html}</tbody></table>"
        f"<p>Detected: {html.escape(detected_at)}</p>"
        "</body></html>"
    )
    text_body = "\n".join([
        f"[{sev}] External Diff Alert: {source_key}",
        f"Rule: {rule.rule_name}",
        f"Reason: {reason}",
        f"Detected: {detected_at}",
    ])
    return {"subject": subject, "html": html_body, "text": text_body}


def dispatch_batch_scan_http(
    items: list[dict[str, Any]],
    endpoint_url: str,
    auth_header_value: str,
    dry_run: bool = True,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> dict[str, Any]:
    """Invoke core-hub external_diff.batch_scan or return dry-run preview."""
    payload = {
        "action": "external_diff.batch_scan",
        "dry_run": dry_run,
        "items": items,
    }
    if dry_run:
        return {
            "mode": "dry_run",
            "dispatched": False,
            "item_count": len(items),
            "payload_preview": payload,
        }
    req = urllib.request.Request(
        endpoint_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {auth_header_value}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with opener(req, timeout=20) as resp:
        raw = resp.read().decode("utf-8")
        return {
            "mode": "live",
            "dispatched": True,
            "status_code": getattr(resp, "status", 200),
            "response": json.loads(raw),
        }


def run_self_test() -> int:
    previous = {"orders": 100, "error_rate": 1.2, "status": "healthy"}
    current = {"orders": 140, "error_rate": 8.5, "status": "degraded"}
    diffs = compute_structured_diff(previous, current)
    assert len(diffs) == 3, f"expected 3 diffs, got {len(diffs)}"

    rule = TriggerRule(
        rule_id="rule-self",
        rule_name="Error spike",
        source_key="checkout_api",
        field_path="error_rate",
        operator="gt",
        threshold_value="5.0",
        severity="critical",
        recipient_email="ops@example.test",
    )
    matches = evaluate_diff_rules([rule], "checkout_api", diffs, current)
    assert len(matches) == 1, "expected rule match"

    now_iso = datetime.now(timezone.utc).isoformat()
    mail = format_email_alert_payload(
        "checkout_api", rule, matches[0]["reason"], diffs, now_iso
    )
    assert "External Diff Alert" in mail["subject"]

    dry = dispatch_batch_scan_http(
        items=[{"user_id": "u-self", "source_key": "checkout_api", "payload": current}],
        endpoint_url=DEFAULT_CORE_HUB_URL,
        auth_header_value="",
        dry_run=True,
    )
    assert dry["dispatched"] is False
    print(
        f"SELF_TEST_PASS diffs={len(diffs)} matches={len(matches)} "
        f"mode={dry['mode']}"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument(
        "--dry-run",
        action=argparse.BooleanOptionalAction,
        default=True,
    )
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--json-out", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()

    sample_prev = {"active_users": 210, "error_count": 1}
    sample_curr = {"active_users": 225, "error_count": 7}
    diffs = compute_structured_diff(sample_prev, sample_curr)
    rule = TriggerRule(
        rule_id="cron-rule-1",
        rule_name="Error count elevated",
        source_key="external_metrics",
        field_path="error_count",
        operator="gt",
        threshold_value="5",
        severity="warning",
    )
    matches = evaluate_diff_rules([rule], "external_metrics", diffs, sample_curr)

    is_live = bool(args.live) or (args.dry_run is False)
    service_cred = (os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if is_live and service_cred:
        dispatch = dispatch_batch_scan_http(
            items=[],
            endpoint_url=DEFAULT_CORE_HUB_URL,
            auth_header_value=service_cred,
            dry_run=False,
        )
    else:
        dispatch = dispatch_batch_scan_http(
            items=[],
            endpoint_url=DEFAULT_CORE_HUB_URL,
            auth_header_value="",
            dry_run=True,
        )

    report = {
        "diffs": [asdict(d) for d in diffs],
        "matches": matches,
        "dispatch": dispatch,
    }
    if args.json_out:
        args.json_out.write_text(
            json.dumps(report, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
    print(f"EXTERNAL_DIFF_RUN diffs={len(diffs)} matches={len(matches)} mode={dispatch['mode']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
