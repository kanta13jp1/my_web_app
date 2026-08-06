from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from activation_experiment_report import (  # noqa: E402
    ReportContractError,
    build_report,
    fetch_arm_rows,
    render_markdown,
    validate_arm_rows,
    wilson_interval,
)


def fixture_rows(*, onboarding_views: int = 0) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index in range(1, 11):
        hypothesis_id = f"a{index:02d}"
        for variant in ("control", "treatment"):
            rows.append(
                {
                    "hypothesis_id": hypothesis_id,
                    "variant": variant,
                    "unique_onboarding_views": onboarding_views,
                    "unique_intent_selections": 0,
                    "unique_first_action_starts": 0,
                    "unique_first_action_completions": 0,
                    "unique_onboarding_completions": 0,
                    "unique_value_recap_views": 0,
                    "unique_billing_views": 0,
                    "unique_supporter_checkouts": 0,
                    "unique_pro_checkouts": 0,
                    "unique_checkout_starts": 0,
                    "unique_checkout_returns": 0,
                    "first_event_at": None,
                    "last_event_at": None,
                }
            )
    return rows


def update_arm(
    rows: list[dict[str, object]],
    hypothesis_id: str,
    variant: str,
    **counts: int,
) -> None:
    row = next(
        candidate
        for candidate in rows
        if candidate["hypothesis_id"] == hypothesis_id
        and candidate["variant"] == variant
    )
    row.update(counts)


class ActivationExperimentReportTest(unittest.TestCase):
    def test_validates_exact_twenty_arm_contract(self) -> None:
        arms = validate_arm_rows(fixture_rows())
        self.assertEqual(len(arms), 20)
        self.assertIn(("a01", "control"), arms)
        self.assertIn(("a10", "treatment"), arms)

    def test_rejects_missing_duplicate_and_negative_rows(self) -> None:
        rows = fixture_rows()
        with self.assertRaisesRegex(ReportContractError, "missing experiment arms"):
            validate_arm_rows(rows[:-1])

        duplicate = fixture_rows()
        duplicate.append(dict(duplicate[0]))
        with self.assertRaisesRegex(ReportContractError, "duplicate experiment arm"):
            validate_arm_rows(duplicate)

        negative = fixture_rows()
        negative[0]["unique_onboarding_views"] = -1
        with self.assertRaisesRegex(ReportContractError, "must be non-negative"):
            validate_arm_rows(negative)

    def test_wilson_interval_matches_known_range(self) -> None:
        lower, upper = wilson_interval(10, 100)
        self.assertAlmostEqual(lower, 0.0552, places=3)
        self.assertAlmostEqual(upper, 0.1744, places=3)

    def test_never_declares_winner_before_view_gate(self) -> None:
        rows = fixture_rows(onboarding_views=99)
        update_arm(rows, "a01", "control", unique_onboarding_completions=1)
        update_arm(rows, "a01", "treatment", unique_onboarding_completions=40)

        report = build_report(validate_arm_rows(rows))

        self.assertEqual(report["hypotheses"][0]["decision"], "insufficient_data")

    def test_declares_treatment_only_with_lift_and_separated_intervals(self) -> None:
        rows = fixture_rows(onboarding_views=100)
        update_arm(rows, "a01", "control", unique_onboarding_completions=10)
        update_arm(rows, "a01", "treatment", unique_onboarding_completions=30)

        first = build_report(validate_arm_rows(rows))["hypotheses"][0]

        self.assertEqual(first["decision"], "treatment_wins")
        self.assertEqual(
            first["primary_metric"]["key"],
            "onboarding_completion_rate",
        )
        self.assertAlmostEqual(first["relative_primary_lift"], 2.0)

    def test_each_hypothesis_uses_its_declared_primary_metric(self) -> None:
        rows = fixture_rows(onboarding_views=200)
        for hypothesis_id in (f"a{index:02d}" for index in range(1, 11)):
            for variant in ("control", "treatment"):
                update_arm(
                    rows,
                    hypothesis_id,
                    variant,
                    unique_first_action_starts=80,
                    unique_first_action_completions=30,
                    unique_onboarding_completions=50,
                    unique_value_recap_views=45,
                    unique_billing_views=20,
                    unique_checkout_starts=7,
                )

        report = build_report(validate_arm_rows(rows))
        observed = {
            item["hypothesis_id"]: (
                item["primary_metric"]["key"],
                item["control"]["primary_metric_successes"],
                item["control"]["primary_metric_denominator"],
            )
            for item in report["hypotheses"]
        }
        for hypothesis_id in ("a01", "a06", "a07", "a08"):
            self.assertEqual(
                observed[hypothesis_id],
                ("onboarding_completion_rate", 50, 200),
            )
        for hypothesis_id in ("a02", "a03", "a04"):
            self.assertEqual(
                observed[hypothesis_id],
                ("first_action_start_rate", 80, 200),
            )
        self.assertEqual(
            observed["a05"],
            ("first_action_completion_rate", 30, 80),
        )
        self.assertEqual(observed["a09"], ("billing_view_rate", 20, 45))
        self.assertEqual(observed["a10"], ("checkout_start_rate", 7, 20))

    def test_a10_requires_five_checkout_starts(self) -> None:
        rows = fixture_rows(onboarding_views=100)
        for variant in ("control", "treatment"):
            update_arm(rows, "a10", variant, unique_billing_views=20)
        update_arm(rows, "a10", "treatment", unique_checkout_starts=4)

        a10 = build_report(validate_arm_rows(rows))["hypotheses"][-1]

        self.assertEqual(
            a10["primary_metric"]["minimum_total_successes"],
            5,
        )
        self.assertFalse(a10["primary_success_gate_ready"])
        self.assertEqual(a10["decision"], "insufficient_data")

    def test_downstream_metrics_require_their_own_denominator_gate(self) -> None:
        rows = fixture_rows(onboarding_views=200)
        update_arm(
            rows,
            "a09",
            "control",
            unique_value_recap_views=19,
            unique_billing_views=1,
        )
        update_arm(
            rows,
            "a09",
            "treatment",
            unique_value_recap_views=19,
            unique_billing_views=15,
        )

        a09 = build_report(validate_arm_rows(rows))["hypotheses"][8]

        self.assertFalse(a09["metric_denominator_gate_ready"])
        self.assertEqual(a09["decision"], "insufficient_data")

    def test_marks_impossible_funnel_counts_invalid(self) -> None:
        rows = fixture_rows(onboarding_views=200)
        update_arm(
            rows,
            "a10",
            "control",
            unique_billing_views=20,
            unique_checkout_starts=21,
        )
        update_arm(
            rows,
            "a10",
            "treatment",
            unique_billing_views=20,
            unique_checkout_starts=10,
        )

        a10 = build_report(validate_arm_rows(rows))["hypotheses"][-1]

        self.assertFalse(a10["metric_contract_valid"])
        self.assertIsNone(a10["control"]["primary_rate"])
        self.assertEqual(a10["decision"], "invalid_funnel_data")

    def test_reports_only_aggregate_metrics(self) -> None:
        report = build_report(validate_arm_rows(fixture_rows()))
        markdown = render_markdown(report)
        encoded = json.dumps(report)

        self.assertFalse(report["privacy"]["contains_auth_user_ids"])
        self.assertFalse(report["privacy"]["contains_raw_events"])
        self.assertNotIn('"auth_user_id"', encoded)
        self.assertIn("A01", markdown)
        self.assertIn("A10", markdown)
        hypothesis_rows = [
            line
            for line in markdown.splitlines()
            if line.startswith("| A") and line[3:5].isdigit()
        ]
        self.assertEqual(len(hypothesis_rows), 10)

    @patch("activation_experiment_report.urllib.request.urlopen")
    def test_fetches_only_service_role_aggregate_view(self, urlopen) -> None:
        response = urlopen.return_value.__enter__.return_value
        response.read.return_value = json.dumps(fixture_rows()).encode("utf-8")

        rows = fetch_arm_rows(
            "https://example.supabase.co",
            "service-role-test-key",
        )

        self.assertEqual(len(rows), 20)
        request = urlopen.call_args.args[0]
        self.assertIn("activation_experiment_arm_stats", request.full_url)
        self.assertNotIn("activation_experiment_events?", request.full_url)
        self.assertEqual(
            request.get_header("Authorization"),
            "Bearer service-role-test-key",
        )

    def test_workflow_never_exposes_service_role_to_pull_requests(self) -> None:
        workflow = (
            REPO_ROOT / ".github" / "workflows"
            / "activation-experiment-report.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("SUPABASE_SERVICE_ROLE_KEY", workflow)
        self.assertNotIn("pull_request:", workflow)


if __name__ == "__main__":
    unittest.main()
