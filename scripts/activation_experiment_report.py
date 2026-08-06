#!/usr/bin/env python3
"""Build a privacy-safe decision report for A01-A10 activation experiments.

The production view contains aggregate arm counts only. This script requires a
service-role key, validates the expected 20-arm contract, and never emits the
key, authenticated user identifiers, or raw event rows.
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
from typing import Any


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
HYPOTHESES = tuple(f"a{index:02d}" for index in range(1, 11))
VARIANTS = ("control", "treatment")
COUNT_FIELDS = (
    "unique_onboarding_views",
    "unique_intent_selections",
    "unique_first_action_starts",
    "unique_first_action_completions",
    "unique_onboarding_completions",
    "unique_value_recap_views",
    "unique_billing_views",
    "unique_supporter_checkouts",
    "unique_pro_checkouts",
    "unique_checkout_starts",
    "unique_checkout_returns",
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
class MetricSpec:
    key: str
    label: str
    numerator_field: str
    denominator_field: str
    minimum_total_successes: int


METRIC_SPECS = {
    "a01": MetricSpec(
        "onboarding_completion_rate",
        "Onboarding completion / onboarding view",
        "unique_onboarding_completions",
        "unique_onboarding_views",
        20,
    ),
    "a02": MetricSpec(
        "first_action_start_rate",
        "First action start / onboarding view",
        "unique_first_action_starts",
        "unique_onboarding_views",
        20,
    ),
    "a03": MetricSpec(
        "first_action_start_rate",
        "First action start / onboarding view",
        "unique_first_action_starts",
        "unique_onboarding_views",
        20,
    ),
    "a04": MetricSpec(
        "first_action_start_rate",
        "First action start / onboarding view",
        "unique_first_action_starts",
        "unique_onboarding_views",
        20,
    ),
    "a05": MetricSpec(
        "first_action_completion_rate",
        "First action completion / first action start",
        "unique_first_action_completions",
        "unique_first_action_starts",
        20,
    ),
    "a06": MetricSpec(
        "onboarding_completion_rate",
        "Onboarding completion / onboarding view",
        "unique_onboarding_completions",
        "unique_onboarding_views",
        20,
    ),
    "a07": MetricSpec(
        "onboarding_completion_rate",
        "Onboarding completion / onboarding view",
        "unique_onboarding_completions",
        "unique_onboarding_views",
        20,
    ),
    "a08": MetricSpec(
        "onboarding_completion_rate",
        "Onboarding completion / onboarding view",
        "unique_onboarding_completions",
        "unique_onboarding_views",
        20,
    ),
    "a09": MetricSpec(
        "billing_view_rate",
        "Billing view / value recap view",
        "unique_billing_views",
        "unique_value_recap_views",
        20,
    ),
    "a10": MetricSpec(
        "checkout_start_rate",
        "Supporter or Pro checkout / billing view",
        "unique_checkout_starts",
        "unique_billing_views",
        5,
    ),
}


@dataclass(frozen=True)
class ArmStats:
    hypothesis_id: str
    variant: str
    unique_onboarding_views: int
    unique_intent_selections: int
    unique_first_action_starts: int
    unique_first_action_completions: int
    unique_onboarding_completions: int
    unique_value_recap_views: int
    unique_billing_views: int
    unique_supporter_checkouts: int
    unique_pro_checkouts: int
    unique_checkout_starts: int
    unique_checkout_returns: int
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
        raise ReportContractError("activation experiment response must be a list")

    parsed: dict[tuple[str, str], ArmStats] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ReportContractError(
                "every activation experiment row must be an object"
            )
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


def _with_primary_metric(
    arm: ArmStats,
    metric: MetricSpec,
) -> dict[str, Any]:
    arm_data = asdict(arm)
    successes = int(arm_data[metric.numerator_field])
    denominator = int(arm_data[metric.denominator_field])
    contract_valid = successes <= denominator
    if denominator <= 0:
        rate = 0.0
        lower, upper = (0.0, 1.0)
    elif contract_valid:
        rate = successes / denominator
        lower, upper = wilson_interval(successes, denominator)
    else:
        rate = None
        lower, upper = (None, None)
    return {
        **arm_data,
        "primary_metric_successes": successes,
        "primary_metric_denominator": denominator,
        "primary_metric_contract_valid": contract_valid,
        "primary_rate": rate,
        "primary_wilson_95": {"lower": lower, "upper": upper},
    }


def build_report(
    arms: dict[tuple[str, str], ArmStats],
    *,
    minimum_views_per_arm: int = 100,
    minimum_metric_denominator_per_arm: int = 20,
) -> dict[str, Any]:
    if set(arms) != expected_arms():
        raise ReportContractError("build_report requires all 20 validated arms")

    hypotheses: list[dict[str, Any]] = []
    for hypothesis_id in HYPOTHESES:
        metric = METRIC_SPECS[hypothesis_id]
        control = _with_primary_metric(
            arms[(hypothesis_id, "control")],
            metric,
        )
        treatment = _with_primary_metric(
            arms[(hypothesis_id, "treatment")],
            metric,
        )
        views_ready = (
            control["unique_onboarding_views"] >= minimum_views_per_arm
            and treatment["unique_onboarding_views"] >= minimum_views_per_arm
        )
        denominators_ready = (
            control["primary_metric_denominator"]
            >= minimum_metric_denominator_per_arm
            and treatment["primary_metric_denominator"]
            >= minimum_metric_denominator_per_arm
        )
        total_primary_successes = (
            control["primary_metric_successes"]
            + treatment["primary_metric_successes"]
        )
        primary_success_gate_ready = (
            total_primary_successes >= metric.minimum_total_successes
        )
        metric_contract_valid = (
            control["primary_metric_contract_valid"]
            and treatment["primary_metric_contract_valid"]
        )
        control_rate = control["primary_rate"]
        treatment_rate = treatment["primary_rate"]
        relative_lift = (
            (treatment_rate - control_rate) / control_rate
            if control_rate is not None
            and treatment_rate is not None
            and control_rate > 0.0
            else None
        )

        if not metric_contract_valid:
            decision = "invalid_funnel_data"
        elif (
            not views_ready
            or not denominators_ready
            or not primary_success_gate_ready
        ):
            decision = "insufficient_data"
        elif (
            treatment_rate > control_rate
            and (control_rate == 0.0 or relative_lift >= 0.20)
            and treatment["primary_wilson_95"]["lower"]
            > control["primary_wilson_95"]["upper"]
        ):
            decision = "treatment_wins"
        elif (
            treatment_rate < control_rate
            and relative_lift is not None
            and relative_lift <= -0.20
            and control["primary_wilson_95"]["lower"]
            > treatment["primary_wilson_95"]["upper"]
        ):
            decision = "control_wins"
        else:
            decision = "inconclusive"

        hypotheses.append(
            {
                "hypothesis_id": hypothesis_id,
                "primary_metric": asdict(metric),
                "control": control,
                "treatment": treatment,
                "relative_primary_lift": relative_lift,
                "views_gate_ready": views_ready,
                "metric_denominator_gate_ready": denominators_ready,
                "total_primary_successes": total_primary_successes,
                "primary_success_gate_ready": primary_success_gate_ready,
                "metric_contract_valid": metric_contract_valid,
                "decision": decision,
            }
        )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "activation_experiment_arm_stats",
        "privacy": {
            "aggregate_only": True,
            "contains_auth_user_ids": False,
            "contains_raw_events": False,
        },
        "contract": {
            "expected_arm_count": 20,
            "actual_arm_count": len(arms),
            "all_arms_present": True,
        },
        "gates": {
            "minimum_onboarding_views_per_arm": minimum_views_per_arm,
            "minimum_primary_denominator_per_arm":
                minimum_metric_denominator_per_arm,
            "minimum_activation_successes_per_hypothesis": 20,
            "minimum_checkout_starts_for_a10": 5,
            "winner_requires_relative_lift": 0.20,
            "winner_requires_separated_wilson_intervals": True,
        },
        "totals": {
            field: sum(getattr(arm, field) for arm in arms.values())
            for field in COUNT_FIELDS
        },
        "hypotheses": hypotheses,
    }


def _format_rate(arm: dict[str, Any]) -> str:
    raw_rate = arm["primary_rate"]
    if raw_rate is None:
        return "invalid"
    rate = float(raw_rate) * 100.0
    interval = arm["primary_wilson_95"]
    lower = float(interval["lower"]) * 100.0
    upper = float(interval["upper"]) * 100.0
    return f"{rate:.2f}% ({lower:.2f}-{upper:.2f}%)"


def render_markdown(report: dict[str, Any]) -> str:
    gates = report["gates"]
    totals = report["totals"]
    lines = [
        "# Activation experiment decision report",
        "",
        f"Generated: {report['generated_at']}",
        "",
        "This report contains aggregate arm metrics only. "
        "It contains no authenticated user IDs or raw events.",
        "",
        "## Global funnel totals",
        "",
        f"- Onboarding views: {totals['unique_onboarding_views']}",
        f"- Onboarding completions: {totals['unique_onboarding_completions']}",
        f"- Value recap views: {totals['unique_value_recap_views']}",
        f"- Billing views: {totals['unique_billing_views']}",
        f"- Checkout starts: {totals['unique_checkout_starts']}",
        "- Minimum onboarding views per arm: "
        f"{gates['minimum_onboarding_views_per_arm']}",
        "- Minimum primary denominator per arm: "
        f"{gates['minimum_primary_denominator_per_arm']}",
        "- Minimum activation successes per hypothesis: "
        f"{gates['minimum_activation_successes_per_hypothesis']}",
        "- Minimum checkout starts for A10: "
        f"{gates['minimum_checkout_starts_for_a10']}",
        "",
        "## Hypotheses",
        "",
        "| Hypothesis | Primary metric | C success/n | T success/n | "
        "C rate (Wilson 95%) | T rate (Wilson 95%) | Lift | Decision |",
        "|---|---|---:|---:|---:|---:|---:|---|",
    ]
    for hypothesis in report["hypotheses"]:
        control = hypothesis["control"]
        treatment = hypothesis["treatment"]
        lift = hypothesis["relative_primary_lift"]
        lift_text = "n/a" if lift is None else f"{float(lift) * 100.0:.2f}%"
        lines.append(
            "| {hypothesis} | {metric} | {control_counts} | "
            "{treatment_counts} | {control_rate} | {treatment_rate} | "
            "{lift} | {decision} |".format(
                hypothesis=hypothesis["hypothesis_id"].upper(),
                metric=hypothesis["primary_metric"]["label"],
                control_counts=(
                    f"{control['primary_metric_successes']}/"
                    f"{control['primary_metric_denominator']}"
                ),
                treatment_counts=(
                    f"{treatment['primary_metric_successes']}/"
                    f"{treatment['primary_metric_denominator']}"
                ),
                control_rate=_format_rate(control),
                treatment_rate=_format_rate(treatment),
                lift=lift_text,
                decision=hypothesis["decision"],
            )
        )
    lines.extend(
        [
            "",
            "A winner is never declared before both arms reach 100 unique "
            "onboarding views and 20 primary-denominator users, the hypothesis "
            "reaches 20 activation successes (A10: 5 checkout starts), and the "
            "Wilson intervals separate.",
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
        f"{supabase_url.rstrip('/')}/rest/v1/"
        f"activation_experiment_arm_stats?{query}"
    )
    request = urllib.request.Request(
        url,
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Accept": "application/json",
            "User-Agent": "my-web-app-activation-experiment-report/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.read().decode("utf-8", errors="replace")[:500]
        raise ReportContractError(
            f"activation experiment report API returned HTTP "
            f"{exc.code}: {message}"
        ) from exc
    if not isinstance(payload, list):
        raise ReportContractError(
            "activation experiment report API returned non-list JSON"
        )
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
        report = build_report(arms)
        markdown = render_markdown(report)
        write_report(
            args.json_report,
            json.dumps(
                report,
                ensure_ascii=True,
                indent=2,
                allow_nan=False,
            ) + "\n",
        )
        write_report(args.markdown_report, markdown)
    except (ReportContractError, OSError, json.JSONDecodeError) as exc:
        print(f"activation experiment report failed: {exc}", file=sys.stderr)
        return 1

    print(
        "activation experiment report passed: "
        f"20 arms, {report['totals']['unique_checkout_starts']} checkout starts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
