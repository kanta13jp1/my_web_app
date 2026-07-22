#!/usr/bin/env python3
"""Build a privacy-safe decision report for the ten landing-page experiments.

The production view contains aggregate arm counts only. This script requires a
service-role key, validates the expected 20-arm contract, and never emits the
key, visitor identifiers, or raw event rows.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
HYPOTHESES = tuple(f"h{index:02d}" for index in range(1, 11))
VARIANTS = ("control", "treatment")
COUNT_FIELDS = (
    "unique_views",
    "unique_trials",
    "unique_save_ctas",
    "unique_signup_submits",
    "unique_signup_completes",
    "non_anonymous_signup_completes",
)
REPORT_SELECT = ",".join(
    (
        "hypothesis_id",
        "variant",
        *COUNT_FIELDS,
        "first_event_at",
        "last_event_at",
    )
)


class ReportContractError(ValueError):
    """Raised when the production aggregate no longer matches its contract."""


@dataclass(frozen=True)
class ArmStats:
    hypothesis_id: str
    variant: str
    unique_views: int
    unique_trials: int
    unique_save_ctas: int
    unique_signup_submits: int
    unique_signup_completes: int
    non_anonymous_signup_completes: int
    first_event_at: str | None = None
    last_event_at: str | None = None


def expected_arms() -> set[tuple[str, str]]:
    return {
        (hypothesis_id, variant)
        for hypothesis_id in HYPOTHESES
        for variant in VARIANTS
    }


def _non_negative_int(value: Any, field: str, arm_key: tuple[str, str]) -> int:
    if isinstance(value, bool):
        raise ReportContractError(f"{arm_key}: {field} must be an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ReportContractError(
            f"{arm_key}: {field} must be an integer"
        ) from exc
    if parsed < 0:
        raise ReportContractError(f"{arm_key}: {field} must be non-negative")
    return parsed


def validate_arm_rows(rows: Any) -> dict[tuple[str, str], ArmStats]:
    if not isinstance(rows, list):
        raise ReportContractError("landing experiment response must be a list")

    parsed: dict[tuple[str, str], ArmStats] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ReportContractError("every landing experiment row must be an object")
        hypothesis_id = str(row.get("hypothesis_id", ""))
        variant = str(row.get("variant", ""))
        key = (hypothesis_id, variant)
        if key not in expected_arms():
            raise ReportContractError(f"unexpected experiment arm: {key}")
        if key in parsed:
            raise ReportContractError(f"duplicate experiment arm: {key}")

        counts = {
            field: _non_negative_int(row.get(field), field, key)
            for field in COUNT_FIELDS
        }
        for success_field in (
            "unique_trials",
            "unique_save_ctas",
            "unique_signup_submits",
            "unique_signup_completes",
            "non_anonymous_signup_completes",
        ):
            if counts[success_field] > counts["unique_views"]:
                raise ReportContractError(
                    f"{key}: {success_field} cannot exceed unique_views"
                )

        parsed[key] = ArmStats(
            hypothesis_id=hypothesis_id,
            variant=variant,
            **counts,
            first_event_at=row.get("first_event_at"),
            last_event_at=row.get("last_event_at"),
        )

    missing = expected_arms() - set(parsed)
    if missing:
        missing_text = ", ".join(f"{h}/{v}" for h, v in sorted(missing))
        raise ReportContractError(f"missing experiment arms: {missing_text}")
    if len(parsed) != 20:
        raise ReportContractError(f"expected 20 experiment arms, got {len(parsed)}")
    return parsed


def wilson_interval(
    successes: int,
    trials: int,
    z: float = 1.959963984540054,
) -> tuple[float, float]:
    """Return a two-sided Wilson score interval for a binomial proportion."""
    if trials <= 0:
        return (0.0, 1.0)
    if successes < 0 or successes > trials:
        raise ValueError("successes must be between zero and trials")
    proportion = successes / trials
    z_squared = z * z
    denominator = 1.0 + z_squared / trials
    center = (proportion + z_squared / (2.0 * trials)) / denominator
    margin = (
        z
        * math.sqrt(
            proportion * (1.0 - proportion) / trials
            + z_squared / (4.0 * trials * trials)
        )
        / denominator
    )
    return (max(0.0, center - margin), min(1.0, center + margin))


def parse_synthetic_offsets(values: Iterable[str]) -> dict[tuple[str, str], int]:
    offsets: dict[tuple[str, str], int] = {}
    for value in values:
        parts = value.split(":")
        if len(parts) != 3:
            raise ReportContractError(
                "synthetic view offsets must use hypothesis:variant:count"
            )
        hypothesis_id, variant, count_text = parts
        key = (hypothesis_id, variant)
        if key not in expected_arms():
            raise ReportContractError(f"unexpected synthetic offset arm: {key}")
        count = _non_negative_int(count_text, "synthetic_view_offset", key)
        offsets[key] = offsets.get(key, 0) + count
    return offsets


def _arm_report(arm: ArmStats, synthetic_view_offset: int) -> dict[str, Any]:
    effective_views = arm.unique_views - synthetic_view_offset
    if effective_views < 0:
        raise ReportContractError(
            f"{arm.hypothesis_id}/{arm.variant}: synthetic offset exceeds views"
        )
    if arm.unique_signup_submits > effective_views:
        raise ReportContractError(
            f"{arm.hypothesis_id}/{arm.variant}: submits exceed effective views"
        )
    rate = (
        arm.unique_signup_submits / effective_views
        if effective_views > 0
        else 0.0
    )
    lower, upper = wilson_interval(arm.unique_signup_submits, effective_views)
    return {
        **asdict(arm),
        "synthetic_view_offset": synthetic_view_offset,
        "effective_unique_views": effective_views,
        "signup_submit_rate": rate,
        "signup_submit_wilson_95": {"lower": lower, "upper": upper},
    }


def build_report(
    arms: dict[tuple[str, str], ArmStats],
    *,
    synthetic_offsets: dict[tuple[str, str], int] | None = None,
    minimum_views_per_arm: int = 100,
    minimum_total_signup_submits: int = 10,
) -> dict[str, Any]:
    if set(arms) != expected_arms():
        raise ReportContractError("build_report requires all 20 validated arms")
    synthetic_offsets = synthetic_offsets or {}

    arm_reports = {
        key: _arm_report(arm, synthetic_offsets.get(key, 0))
        for key, arm in arms.items()
    }
    total_signup_submits = sum(
        arm.unique_signup_submits for arm in arms.values()
    )
    total_signup_completes = sum(
        arm.unique_signup_completes for arm in arms.values()
    )
    total_non_anonymous_completes = sum(
        arm.non_anonymous_signup_completes for arm in arms.values()
    )
    submit_gate_ready = total_signup_submits >= minimum_total_signup_submits

    hypotheses: list[dict[str, Any]] = []
    for hypothesis_id in HYPOTHESES:
        control = arm_reports[(hypothesis_id, "control")]
        treatment = arm_reports[(hypothesis_id, "treatment")]
        views_ready = (
            control["effective_unique_views"] >= minimum_views_per_arm
            and treatment["effective_unique_views"] >= minimum_views_per_arm
        )
        control_rate = float(control["signup_submit_rate"])
        treatment_rate = float(treatment["signup_submit_rate"])
        relative_lift = (
            (treatment_rate - control_rate) / control_rate
            if control_rate > 0.0
            else None
        )

        if not views_ready or not submit_gate_ready:
            decision = "insufficient_data"
        elif relative_lift is None:
            decision = "inconclusive"
        elif (
            relative_lift >= 0.20
            and treatment["signup_submit_wilson_95"]["lower"]
            > control["signup_submit_wilson_95"]["upper"]
        ):
            decision = "treatment_wins"
        elif (
            relative_lift <= -0.20
            and control["signup_submit_wilson_95"]["lower"]
            > treatment["signup_submit_wilson_95"]["upper"]
        ):
            decision = "control_wins"
        else:
            decision = "inconclusive"

        hypotheses.append(
            {
                "hypothesis_id": hypothesis_id,
                "control": control,
                "treatment": treatment,
                "relative_signup_submit_lift": relative_lift,
                "views_gate_ready": views_ready,
                "global_signup_submit_gate_ready": submit_gate_ready,
                "decision": decision,
            }
        )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "landing_experiment_arm_stats",
        "privacy": {
            "aggregate_only": True,
            "contains_visitor_ids": False,
            "contains_raw_events": False,
        },
        "contract": {
            "expected_arm_count": 20,
            "actual_arm_count": len(arms),
            "all_arms_present": True,
        },
        "gates": {
            "minimum_views_per_arm": minimum_views_per_arm,
            "minimum_total_signup_submits": minimum_total_signup_submits,
            "total_signup_submits": total_signup_submits,
            "total_signup_completes": total_signup_completes,
            "total_non_anonymous_signup_completes": total_non_anonymous_completes,
            "global_signup_submit_gate_ready": submit_gate_ready,
            "auth_and_performance_guardrail": "requires_separate_telemetry",
        },
        "hypotheses": hypotheses,
    }


def _format_rate(arm: dict[str, Any]) -> str:
    rate = float(arm["signup_submit_rate"]) * 100.0
    interval = arm["signup_submit_wilson_95"]
    lower = float(interval["lower"]) * 100.0
    upper = float(interval["upper"]) * 100.0
    return f"{rate:.2f}% ({lower:.2f}-{upper:.2f}%)"


def render_markdown(report: dict[str, Any]) -> str:
    gates = report["gates"]
    lines = [
        "# Landing experiment decision report",
        "",
        f"Generated: {report['generated_at']}",
        "",
        "This report contains aggregate arm metrics only. "
        "It contains no visitor IDs or raw events.",
        "",
        "## Global gates",
        "",
        "- Signup submits: "
        f"{gates['total_signup_submits']} / "
        f"{gates['minimum_total_signup_submits']}",
        f"- Signup completes: {gates['total_signup_completes']}",
        f"- Non-anonymous signup completes: {gates['total_non_anonymous_signup_completes']}",
        f"- Submit gate ready: {str(gates['global_signup_submit_gate_ready']).lower()}",
        f"- Auth/performance guardrail: {gates['auth_and_performance_guardrail']}",
        "",
        "## Hypotheses",
        "",
        "| Hypothesis | C views | T views | C submit CVR (Wilson 95%) | "
        "T submit CVR (Wilson 95%) | Relative lift | Decision |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    for hypothesis in report["hypotheses"]:
        control = hypothesis["control"]
        treatment = hypothesis["treatment"]
        lift = hypothesis["relative_signup_submit_lift"]
        lift_text = "n/a" if lift is None else f"{float(lift) * 100.0:.2f}%"
        lines.append(
            "| {hypothesis} | {control_views} | {treatment_views} | {control_rate} | "
            "{treatment_rate} | {lift} | {decision} |".format(
                hypothesis=hypothesis["hypothesis_id"].upper(),
                control_views=control["effective_unique_views"],
                treatment_views=treatment["effective_unique_views"],
                control_rate=_format_rate(control),
                treatment_rate=_format_rate(treatment),
                lift=lift_text,
                decision=hypothesis["decision"],
            )
        )
    lines.extend(
        [
            "",
            "A winner is never declared before both arms reach the view gate "
            "and the global submit gate is ready.",
            "",
        ]
    )
    return "\n".join(lines)


def fetch_arm_rows(
    supabase_url: str,
    service_role_key: str,
    *,
    timeout: int = 20,
) -> list[dict[str, Any]]:
    if not service_role_key.strip():
        raise ReportContractError("SUPABASE_SERVICE_ROLE_KEY is required")
    query = urllib.parse.urlencode(
        {
            "select": REPORT_SELECT,
            "order": "hypothesis_id.asc,variant.asc",
        }
    )
    url = (
        f"{supabase_url.rstrip('/')}/rest/v1/landing_experiment_arm_stats?{query}"
    )
    request = urllib.request.Request(
        url,
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Accept": "application/json",
            "User-Agent": "my-web-app-landing-experiment-report/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.read().decode("utf-8", errors="replace")[:500]
        raise ReportContractError(
            f"landing experiment report API returned HTTP {exc.code}: {message}"
        ) from exc
    if not isinstance(payload, list):
        raise ReportContractError("landing experiment report API returned non-list JSON")
    return payload


def write_report(path: str, content: str) -> None:
    report_path = Path(path)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(content, encoding="utf-8")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--supabase-url",
        default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL),
    )
    parser.add_argument("--json-report", required=True)
    parser.add_argument("--markdown-report", required=True)
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument(
        "--synthetic-view-offset",
        action="append",
        default=[],
        help="Aggregate-only QA correction in hypothesis:variant:count form.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    try:
        rows = fetch_arm_rows(
            args.supabase_url,
            service_role_key,
            timeout=args.timeout,
        )
        arms = validate_arm_rows(rows)
        offsets = parse_synthetic_offsets(args.synthetic_view_offset)
        report = build_report(arms, synthetic_offsets=offsets)
        markdown = render_markdown(report)
        write_report(
            args.json_report,
            json.dumps(report, ensure_ascii=True, indent=2, allow_nan=False) + "\n",
        )
        write_report(args.markdown_report, markdown)
    except (ReportContractError, OSError, json.JSONDecodeError) as exc:
        print(f"landing experiment report failed: {exc}", file=sys.stderr)
        return 1

    print(
        "landing experiment report passed: "
        f"20 arms, {report['gates']['total_signup_submits']} signup submits"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
