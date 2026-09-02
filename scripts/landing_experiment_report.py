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
    "unique_hero_ctas",
    "unique_intents",
    "unique_mobile_views",
    "unique_mobile_signup_submits",
    "unique_sticky_ctas",
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
FUNNEL_EVENT_KEYS = (
    "funnel_trial_run",
    "funnel_save_cta",
    "funnel_magic_link_attempt",
    "funnel_magic_link_send",
    "funnel_magic_link_fail_invalid_email",
    "funnel_magic_link_fail_rate_limit",
    "funnel_magic_link_fail_delivery_config",
    "funnel_magic_link_fail_redirect",
    "funnel_magic_link_fail_network",
    "funnel_magic_link_fail_unknown",
    "funnel_google_oauth_start",
    "funnel_google_oauth_fail_cancelled",
    "funnel_google_oauth_fail_rate_limit",
    "funnel_google_oauth_fail_provider_config",
    "funnel_google_oauth_fail_redirect",
    "funnel_google_oauth_fail_callback_exchange",
    "funnel_google_oauth_fail_unknown",
    "funnel_inbox_open",
)


class ReportContractError(ValueError):
    """Raised when the production aggregate no longer matches its contract."""


@dataclass(frozen=True)
class MetricSpec:
    key: str
    label: str
    numerator_field: str
    denominator_field: str


METRIC_SPECS = {
    "h01": MetricSpec(
        "hero_cta_rate",
        "Hero CTA / view",
        "unique_hero_ctas",
        "effective_unique_views",
    ),
    "h02": MetricSpec(
        "trial_start_rate",
        "Trial / view",
        "unique_trials",
        "effective_unique_views",
    ),
    "h03": MetricSpec(
        "signup_submit_rate",
        "Signup submit / view",
        "unique_signup_submits",
        "effective_unique_views",
    ),
    "h04": MetricSpec(
        "signup_submit_rate",
        "Signup submit / view",
        "unique_signup_submits",
        "effective_unique_views",
    ),
    "h05": MetricSpec(
        "hero_cta_rate",
        "Hero CTA / view",
        "unique_hero_ctas",
        "effective_unique_views",
    ),
    "h06": MetricSpec(
        "trial_start_rate",
        "Trial / view",
        "unique_trials",
        "effective_unique_views",
    ),
    "h07": MetricSpec(
        "signup_submit_rate",
        "Signup submit / view",
        "unique_signup_submits",
        "effective_unique_views",
    ),
    "h08": MetricSpec(
        "signup_completion_rate",
        "Verified signup / signup submit",
        "non_anonymous_signup_completes",
        "unique_signup_submits",
    ),
    "h09": MetricSpec(
        "mobile_signup_submit_rate",
        "Mobile signup submit / mobile view",
        "unique_mobile_signup_submits",
        "unique_mobile_views",
    ),
    "h10": MetricSpec(
        "trial_save_rate",
        "Save CTA / trial",
        "unique_save_ctas",
        "unique_trials",
    ),
}


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
    unique_hero_ctas: int
    unique_intents: int
    unique_mobile_views: int
    unique_mobile_signup_submits: int
    unique_sticky_ctas: int
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


def experiment_observation_window(
    arms: dict[tuple[str, str], ArmStats],
) -> tuple[str | None, str | None]:
    dates: list[str] = []
    for arm in arms.values():
        for value in (arm.first_event_at, arm.last_event_at):
            if not value:
                continue
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError as exc:
                raise ReportContractError(
                    f"invalid experiment event timestamp: {value}"
                ) from exc
            dates.append(parsed.date().isoformat())
    if not dates:
        return (None, None)
    return (min(dates), max(dates))


def summarize_funnel_rows(rows: Any) -> dict[str, int]:
    if not isinstance(rows, list):
        raise ReportContractError("app analytics response must be a list")

    totals = {event_key: 0 for event_key in FUNNEL_EVENT_KEYS}
    for row in rows:
        if not isinstance(row, dict):
            raise ReportContractError("every app analytics row must be an object")
        source_details = row.get("source_details")
        if source_details is None:
            continue
        if not isinstance(source_details, dict):
            raise ReportContractError("app analytics source_details must be an object")
        for event_key in FUNNEL_EVENT_KEYS:
            value = source_details.get(event_key, 0)
            if isinstance(value, bool):
                raise ReportContractError(
                    f"app analytics {event_key} must be an integer"
                )
            if isinstance(value, float) and not value.is_integer():
                raise ReportContractError(
                    f"app analytics {event_key} must be an integer"
                )
            try:
                count = int(value)
            except (TypeError, ValueError) as exc:
                raise ReportContractError(
                    f"app analytics {event_key} must be an integer"
                ) from exc
            if count < 0:
                raise ReportContractError(
                    f"app analytics {event_key} must be non-negative"
                )
            totals[event_key] += count
    return totals


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
    return {
        **asdict(arm),
        "synthetic_view_offset": synthetic_view_offset,
        "effective_unique_views": effective_views,
    }


def _with_primary_metric(
    arm: dict[str, Any],
    metric: MetricSpec,
) -> dict[str, Any]:
    successes = int(arm[metric.numerator_field])
    denominator = int(arm[metric.denominator_field])
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
        **arm,
        "primary_metric_successes": successes,
        "primary_metric_denominator": denominator,
        "primary_metric_contract_valid": contract_valid,
        "primary_rate": rate,
        "primary_wilson_95": {"lower": lower, "upper": upper},
    }


def build_report(
    arms: dict[tuple[str, str], ArmStats],
    *,
    synthetic_offsets: dict[tuple[str, str], int] | None = None,
    funnel_counts: dict[str, int] | None = None,
    funnel_observation_window: tuple[str | None, str | None] = (None, None),
    minimum_views_per_arm: int = 100,
    minimum_metric_denominator_per_arm: int = 20,
    minimum_total_primary_successes: int = 10,
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
    global_submit_gate_ready = (
        total_signup_submits >= minimum_total_primary_successes
    )
    observed_funnel = funnel_counts or {}
    magic_link_failures = {
        "invalid_email": observed_funnel.get(
            "funnel_magic_link_fail_invalid_email"
        ),
        "rate_limit": observed_funnel.get(
            "funnel_magic_link_fail_rate_limit"
        ),
        "delivery_configuration": observed_funnel.get(
            "funnel_magic_link_fail_delivery_config"
        ),
        "redirect_configuration": observed_funnel.get(
            "funnel_magic_link_fail_redirect"
        ),
        "network": observed_funnel.get("funnel_magic_link_fail_network"),
        "unknown": observed_funnel.get("funnel_magic_link_fail_unknown"),
    }
    magic_link_failure_total = (
        sum(value or 0 for value in magic_link_failures.values())
        if funnel_counts is not None
        else None
    )
    magic_link_attempts = observed_funnel.get("funnel_magic_link_attempt")
    magic_link_sends = observed_funnel.get("funnel_magic_link_send")
    google_oauth_starts = observed_funnel.get("funnel_google_oauth_start")
    google_oauth_failures = {
        "cancelled": observed_funnel.get("funnel_google_oauth_fail_cancelled"),
        "rate_limit": observed_funnel.get("funnel_google_oauth_fail_rate_limit"),
        "provider_configuration": observed_funnel.get(
            "funnel_google_oauth_fail_provider_config"
        ),
        "redirect_configuration": observed_funnel.get(
            "funnel_google_oauth_fail_redirect"
        ),
        "callback_exchange": observed_funnel.get(
            "funnel_google_oauth_fail_callback_exchange"
        ),
        "unknown": observed_funnel.get("funnel_google_oauth_fail_unknown"),
    }
    google_oauth_failure_total = (
        sum(value or 0 for value in google_oauth_failures.values())
        if funnel_counts is not None
        else None
    )

    if funnel_counts is None:
        recommended_next_action = "fetch_auth_handoff_diagnostics"
    elif (observed_funnel.get("funnel_save_cta") or 0) == 0:
        recommended_next_action = "increase_qualified_trial_and_save_cta_traffic"
    elif (magic_link_attempts or 0) + (google_oauth_starts or 0) == 0:
        recommended_next_action = "improve_registration_cta_handoff"
    elif (magic_link_attempts or 0) > 0 and (magic_link_sends or 0) == 0:
        recommended_next_action = "repair_magic_link_delivery_or_use_google_oauth"
    elif (google_oauth_failure_total or 0) > 0 and total_non_anonymous_completes == 0:
        recommended_next_action = "repair_google_oauth_callback_failure"
    elif total_non_anonymous_completes == 0:
        recommended_next_action = "verify_oauth_callback_and_signup_completion"
    else:
        recommended_next_action = "move_activated_users_to_checkout"

    funnel_diagnostics = {
        "status": "available" if funnel_counts is not None else "not_fetched",
        "observation_start": funnel_observation_window[0],
        "observation_end": funnel_observation_window[1],
        "counting": "aggregate_events_not_unique_visitors",
        "trial_runs": observed_funnel.get("funnel_trial_run"),
        "save_ctas": observed_funnel.get("funnel_save_cta"),
        "magic_link_attempts": magic_link_attempts,
        "magic_link_sends": magic_link_sends,
        "magic_link_failures": magic_link_failures,
        "magic_link_failure_total": magic_link_failure_total,
        "google_oauth_starts": google_oauth_starts,
        "google_oauth_failures": google_oauth_failures,
        "google_oauth_failure_total": google_oauth_failure_total,
        "inbox_opens": observed_funnel.get("funnel_inbox_open"),
        "recommended_next_action": recommended_next_action,
    }

    hypotheses: list[dict[str, Any]] = []
    for hypothesis_id in HYPOTHESES:
        metric = METRIC_SPECS[hypothesis_id]
        control = _with_primary_metric(
            arm_reports[(hypothesis_id, "control")],
            metric,
        )
        treatment = _with_primary_metric(
            arm_reports[(hypothesis_id, "treatment")],
            metric,
        )
        views_ready = (
            control["effective_unique_views"] >= minimum_views_per_arm
            and treatment["effective_unique_views"] >= minimum_views_per_arm
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
            total_primary_successes >= minimum_total_primary_successes
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
            "minimum_metric_denominator_per_arm":
                minimum_metric_denominator_per_arm,
            "minimum_total_primary_successes":
                minimum_total_primary_successes,
            "total_signup_submits": total_signup_submits,
            "total_signup_completes": total_signup_completes,
            "total_non_anonymous_signup_completes": total_non_anonymous_completes,
            "global_signup_submit_gate_ready": global_submit_gate_ready,
            "auth_and_performance_guardrail": "requires_separate_telemetry",
        },
        "funnel_diagnostics": funnel_diagnostics,
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
    funnel = report["funnel_diagnostics"]
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
        f"{gates['total_signup_submits']}",
        f"- Signup completes: {gates['total_signup_completes']}",
        f"- Non-anonymous signup completes: {gates['total_non_anonymous_signup_completes']}",
        "- Minimum views per arm: "
        f"{gates['minimum_views_per_arm']}",
        "- Minimum primary-metric denominator per arm: "
        f"{gates['minimum_metric_denominator_per_arm']}",
        "- Minimum primary successes per hypothesis: "
        f"{gates['minimum_total_primary_successes']}",
        f"- Auth/performance guardrail: {gates['auth_and_performance_guardrail']}",
        "",
        "## Signup handoff diagnostics",
        "",
        f"- Status: {funnel['status']}",
        "- Observation window: "
        f"{funnel['observation_start'] or 'unknown'} to "
        f"{funnel['observation_end'] or 'unknown'}",
        f"- Trial runs: {funnel['trial_runs'] if funnel['trial_runs'] is not None else 'missing'}",
        f"- Save CTA events: {funnel['save_ctas'] if funnel['save_ctas'] is not None else 'missing'}",
        "- Magic Link attempts: "
        f"{funnel['magic_link_attempts'] if funnel['magic_link_attempts'] is not None else 'missing'}",
        "- Successful Magic Link sends: "
        f"{funnel['magic_link_sends'] if funnel['magic_link_sends'] is not None else 'missing'}",
        "- Categorized Magic Link failures: "
        f"{funnel['magic_link_failure_total'] if funnel['magic_link_failure_total'] is not None else 'missing'}",
        "- Google OAuth starts: "
        f"{funnel['google_oauth_starts'] if funnel['google_oauth_starts'] is not None else 'missing'}",
        "- Categorized Google OAuth callback failures: "
        f"{funnel['google_oauth_failure_total'] if funnel['google_oauth_failure_total'] is not None else 'missing'}",
        f"- Inbox opens: {funnel['inbox_opens'] if funnel['inbox_opens'] is not None else 'missing'}",
        f"- Recommended next action: {funnel['recommended_next_action']}",
        "- Counting note: aggregate event counts, not unique visitors.",
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
            "| {hypothesis} | {metric} | {control_counts} | {treatment_counts} | "
            "{control_rate} | {treatment_rate} | {lift} | {decision} |".format(
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
            "A winner is never declared before both arms reach the view and "
            "primary-metric denominator gates, the hypothesis reaches its "
            "primary-success gate, and the Wilson intervals separate.",
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


def fetch_funnel_rows(
    supabase_url: str,
    service_role_key: str,
    *,
    start_date: str | None = None,
    end_date: str | None = None,
    timeout: int = 20,
) -> list[dict[str, Any]]:
    if not service_role_key.strip():
        raise ReportContractError("SUPABASE_SERVICE_ROLE_KEY is required")
    query_parameters = {
        "select": "date,source_details",
        "order": "date.asc",
    }
    if start_date:
        query_parameters["date"] = f"gte.{start_date}"
    if end_date:
        query_parameters["and"] = f"(date.lte.{end_date})"
    query = urllib.parse.urlencode(query_parameters)
    url = f"{supabase_url.rstrip('/')}/rest/v1/app_analytics?{query}"
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
            f"signup handoff report API returned HTTP {exc.code}: {message}"
        ) from exc
    if not isinstance(payload, list):
        raise ReportContractError("signup handoff report API returned non-list JSON")
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
        observation_window = experiment_observation_window(arms)
        funnel_rows = fetch_funnel_rows(
            args.supabase_url,
            service_role_key,
            start_date=observation_window[0],
            end_date=observation_window[1],
            timeout=args.timeout,
        )
        funnel_counts = summarize_funnel_rows(funnel_rows)
        report = build_report(
            arms,
            synthetic_offsets=offsets,
            funnel_counts=funnel_counts,
            funnel_observation_window=observation_window,
        )
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
