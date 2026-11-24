#!/usr/bin/env python3
"""Deterministic monthly KPI closing report generator & CI gate (#2772)."""

from __future__ import annotations

import argparse
import calendar
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


SAMPLE_KPIS: list[dict[str, Any]] = [
    {
        "month_key": "2026-11",
        "annual_goal": "持続可能な開発・学習の継続",
        "metric_name": "完了タスク数",
        "target_value": 20,
        "actual_value": 18,
        "unit": "件",
        "reflection": "優先順位を固定して着実に前進。",
        "next_action": "翌月も上位3件を先に完了する。",
    },
    {
        "month_key": "2026-11",
        "annual_goal": "持続可能な開発・学習の継続",
        "metric_name": "振り返り記録日数",
        "target_value": 25,
        "actual_value": 25,
        "unit": "日",
        "reflection": "毎日の小記録を途切れず継続。",
        "next_action": "週末レビューを定時化する。",
    },
]


def is_month_end(date_obj: dt.date) -> bool:
    last_day = calendar.monthrange(date_obj.year, date_obj.month)[1]
    return date_obj.day == last_day


def _format_num(value: float) -> str:
    if value == int(value):
        return str(int(value))
    return f"{value:.1f}"


def compute_closing_report(
    items: list[dict[str, Any]],
    month_key: str,
    generated_at: str | None = None,
) -> dict[str, Any]:
    if not isinstance(items, list):
        raise ValueError("KPI items must be a JSON array")

    monthly: list[dict[str, Any]] = []
    for idx, raw in enumerate(items):
        if not isinstance(raw, dict):
            raise ValueError(f"KPI item at index {idx} must be an object")
        if str(raw.get("month_key", "")).strip() != month_key:
            continue
        metric_name = str(raw.get("metric_name", "")).strip()
        if not metric_name:
            raise ValueError(f"KPI item at index {idx} is missing metric_name")
        target = float(raw.get("target_value", 0) or 0)
        actual = float(raw.get("actual_value", 0) or 0)
        if target < 0 or actual < 0:
            raise ValueError(
                f"KPI item '{metric_name}' cannot have negative values",
            )
        rate = (actual / target) if target > 0 else 0.0
        capped = min(max(rate, 0.0), 1.0)
        completed = target > 0 and actual >= target
        monthly.append(
            {
                "annual_goal": str(raw.get("annual_goal", "")).strip(),
                "metric_name": metric_name,
                "target_value": target,
                "actual_value": actual,
                "unit": str(raw.get("unit", "")).strip(),
                "reflection": str(raw.get("reflection", "")).strip(),
                "next_action": str(raw.get("next_action", "")).strip(),
                "progress_percent": round(rate * 100),
                "capped_progress": capped,
                "completed": completed,
            }
        )

    total_metrics = len(monthly)
    completed_metrics = sum(1 for item in monthly if item["completed"])
    avg_progress_pct = (
        round(
            (sum(item["capped_progress"] for item in monthly) / total_metrics)
            * 100
        )
        if total_metrics > 0
        else 0
    )
    primary_goal = next(
        (item["annual_goal"] for item in monthly if item["annual_goal"]),
        "TBD",
    )

    lines = [
        f"# Career Monthly Close: {month_key}",
        "",
        f"- Annual goal: {primary_goal}",
        f"- Metrics: {completed_metrics}/{total_metrics} complete",
        f"- Average progress: {avg_progress_pct}%",
        "",
        "## KPI Review",
    ]
    if not monthly:
        lines.extend(
            [
                "- No monthly KPI records yet.",
                "",
                "## Next Month Focus",
                "- Define one measurable career KPI before the first weekly review.",
            ]
        )
    else:
        for item in monthly:
            u = item["unit"]
            lines.extend(
                [
                    f"- {item['metric_name']}: "
                    f"{_format_num(item['actual_value'])}{u} / "
                    f"{_format_num(item['target_value'])}{u} "
                    f"({item['progress_percent']}%)",
                    f"  - Reflection: {item['reflection'] or 'TBD'}",
                    f"  - Next action: {item['next_action'] or 'TBD'}",
                ]
            )

    markdown = "\n".join(lines)
    checksum = hashlib.sha256(markdown.encode("utf-8")).hexdigest()[:16]

    return {
        "month_key": month_key,
        "generated_at": generated_at or dt.datetime.now(dt.timezone.utc).isoformat(),
        "primary_goal": primary_goal,
        "total_metrics": total_metrics,
        "completed_metrics": completed_metrics,
        "average_progress_percent": avg_progress_pct,
        "checksum": checksum,
        "markdown_report": markdown,
        "metrics": monthly,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate deterministic monthly KPI closing report.",
    )
    parser.add_argument("--month", help="Target YYYY-MM month key")
    parser.add_argument("--today", help="Override ISO YYYY-MM-DD date")
    parser.add_argument(
        "--check-month-end",
        action="store_true",
        help="Skip unless today is the last day of its month",
    )
    parser.add_argument("--input", help="Path to JSON array of KPI records")
    parser.add_argument(
        "--self-check",
        action="store_true",
        help="Run using built-in deterministic fixture items",
    )
    parser.add_argument("--output-json", help="Write summary JSON here")
    parser.add_argument("--output-md", help="Write markdown report here")
    args = parser.parse_args(argv)

    today = (
        dt.date.fromisoformat(args.today)
        if args.today
        else dt.date.today()
    )
    month_key = args.month or f"{today.year:04d}-{today.month:02d}"

    if args.check_month_end and not is_month_end(today):
        print(
            json.dumps(
                {
                    "status": "skipped_not_month_end",
                    "today": today.isoformat(),
                    "month_key": month_key,
                },
                ensure_ascii=False,
            )
        )
        return 0

    if args.input:
        raw_text = Path(args.input).read_text(encoding="utf-8")
        items = json.loads(raw_text)
    elif args.self_check:
        month_key = args.month or "2026-11"
        items = [dict(row, month_key=month_key) for row in SAMPLE_KPIS]
    else:
        print(
            "Provide either --input <json> or --self-check",
            file=sys.stderr,
        )
        return 2

    report = compute_closing_report(items, month_key)

    if args.output_json:
        Path(args.output_json).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.output_md:
        Path(args.output_md).write_text(
            report["markdown_report"] + "\n",
            encoding="utf-8",
        )

    print(
        json.dumps(
            {
                "status": "ok",
                "month_key": report["month_key"],
                "total_metrics": report["total_metrics"],
                "completed_metrics": report["completed_metrics"],
                "average_progress_percent": report["average_progress_percent"],
                "checksum": report["checksum"],
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
