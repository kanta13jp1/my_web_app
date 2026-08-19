from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from landing_experiment_report import (  # noqa: E402
    ReportContractError,
    build_report,
    fetch_arm_rows,
    fetch_funnel_rows,
    experiment_observation_window,
    parse_synthetic_offsets,
    render_markdown,
    summarize_funnel_rows,
    validate_arm_rows,
    wilson_interval,
)


def fixture_rows(
    *,
    views: int = 0,
    control_submits: int = 0,
    treatment_submits: int = 0,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index in range(1, 11):
        hypothesis_id = f"h{index:02d}"
        for variant in ("control", "treatment"):
            submits = control_submits if variant == "control" else treatment_submits
            rows.append(
                {
                    "hypothesis_id": hypothesis_id,
                    "variant": variant,
                    "unique_views": views,
                    "unique_trials": min(submits, views),
                    "unique_save_ctas": min(submits, views),
                    "unique_signup_submits": submits,
                    "unique_signup_completes": min(submits, views),
                    "non_anonymous_signup_completes": min(submits, views),
                    "unique_hero_ctas": min(submits, views),
                    "unique_intents": min(submits, views),
                    "unique_mobile_views": views,
                    "unique_mobile_signup_submits": min(submits, views),
                    "unique_sticky_ctas": min(submits, views),
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


class LandingExperimentReportTest(unittest.TestCase):
    def test_validates_exact_twenty_arm_contract(self) -> None:
        arms = validate_arm_rows(fixture_rows())
        self.assertEqual(len(arms), 20)
        self.assertIn(("h01", "control"), arms)
        self.assertIn(("h10", "treatment"), arms)

    def test_rejects_missing_duplicate_and_negative_rows(self) -> None:
        rows = fixture_rows()
        with self.assertRaisesRegex(ReportContractError, "missing experiment arms"):
            validate_arm_rows(rows[:-1])

        duplicate = fixture_rows()
        duplicate.append(dict(duplicate[0]))
        with self.assertRaisesRegex(ReportContractError, "duplicate experiment arm"):
            validate_arm_rows(duplicate)

        negative = fixture_rows()
        negative[0]["unique_views"] = -1
        with self.assertRaisesRegex(ReportContractError, "must be non-negative"):
            validate_arm_rows(negative)

    def test_wilson_interval_matches_known_range(self) -> None:
        lower, upper = wilson_interval(10, 100)
        self.assertAlmostEqual(lower, 0.0552, places=3)
        self.assertAlmostEqual(upper, 0.1744, places=3)

    def test_never_declares_winner_before_sample_gate(self) -> None:
        rows = fixture_rows(views=99)
        update_arm(rows, "h01", "control", unique_hero_ctas=1)
        update_arm(rows, "h01", "treatment", unique_hero_ctas=20)
        arms = validate_arm_rows(rows)
        report = build_report(arms)
        self.assertEqual(
            report["hypotheses"][0]["decision"],
            "insufficient_data",
        )

    def test_declares_treatment_only_with_lift_and_separated_intervals(self) -> None:
        rows = fixture_rows(views=100)
        update_arm(rows, "h01", "control", unique_hero_ctas=10)
        update_arm(rows, "h01", "treatment", unique_hero_ctas=30)
        arms = validate_arm_rows(rows)
        report = build_report(arms)
        first = report["hypotheses"][0]
        self.assertEqual(first["decision"], "treatment_wins")
        self.assertEqual(first["primary_metric"]["key"], "hero_cta_rate")
        self.assertAlmostEqual(first["relative_primary_lift"], 2.0)

    def test_each_hypothesis_uses_its_declared_primary_metric(self) -> None:
        rows = fixture_rows(views=200)
        for hypothesis_id in (f"h{index:02d}" for index in range(1, 11)):
            for variant in ("control", "treatment"):
                update_arm(
                    rows,
                    hypothesis_id,
                    variant,
                    unique_hero_ctas=21,
                    unique_trials=80,
                    unique_save_ctas=17,
                    unique_signup_submits=45,
                    non_anonymous_signup_completes=13,
                    unique_mobile_views=120,
                    unique_mobile_signup_submits=19,
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
        self.assertEqual(observed["h01"], ("hero_cta_rate", 21, 200))
        self.assertEqual(observed["h02"], ("trial_start_rate", 80, 200))
        self.assertEqual(observed["h03"], ("signup_submit_rate", 45, 200))
        self.assertEqual(observed["h04"], ("signup_submit_rate", 45, 200))
        self.assertEqual(observed["h05"], ("hero_cta_rate", 21, 200))
        self.assertEqual(observed["h06"], ("trial_start_rate", 80, 200))
        self.assertEqual(observed["h07"], ("signup_submit_rate", 45, 200))
        self.assertEqual(observed["h08"], ("signup_completion_rate", 13, 45))
        self.assertEqual(
            observed["h09"],
            ("mobile_signup_submit_rate", 19, 120),
        )
        self.assertEqual(observed["h10"], ("trial_save_rate", 17, 80))

    def test_downstream_metrics_require_their_own_denominator_gate(self) -> None:
        rows = fixture_rows(views=200)
        update_arm(
            rows,
            "h10",
            "control",
            unique_trials=19,
            unique_save_ctas=1,
        )
        update_arm(
            rows,
            "h10",
            "treatment",
            unique_trials=19,
            unique_save_ctas=15,
        )

        report = build_report(validate_arm_rows(rows))
        h10 = report["hypotheses"][-1]
        self.assertFalse(h10["metric_denominator_gate_ready"])
        self.assertEqual(h10["decision"], "insufficient_data")

    def test_marks_impossible_funnel_counts_invalid_without_inventing_a_rate(
        self,
    ) -> None:
        rows = fixture_rows(views=200)
        update_arm(
            rows,
            "h10",
            "control",
            unique_trials=20,
            unique_save_ctas=21,
        )
        update_arm(
            rows,
            "h10",
            "treatment",
            unique_trials=20,
            unique_save_ctas=10,
        )

        report = build_report(validate_arm_rows(rows))
        h10 = report["hypotheses"][-1]
        self.assertFalse(h10["metric_contract_valid"])
        self.assertIsNone(h10["control"]["primary_rate"])
        self.assertEqual(h10["decision"], "invalid_funnel_data")

    def test_synthetic_offsets_remove_known_qa_views_from_effective_sample(self) -> None:
        rows = fixture_rows(views=100, control_submits=10, treatment_submits=10)
        for row in rows:
            if row["hypothesis_id"] == "h01" and row["variant"] == "control":
                row["unique_views"] = 101
            if row["hypothesis_id"] == "h10" and row["variant"] == "treatment":
                row["unique_views"] = 101
        arms = validate_arm_rows(rows)
        offsets = parse_synthetic_offsets(
            ["h01:control:1", "h10:treatment:1"]
        )
        report = build_report(arms, synthetic_offsets=offsets)
        h01 = report["hypotheses"][0]
        h10 = report["hypotheses"][-1]
        self.assertEqual(h01["control"]["unique_views"], 101)
        self.assertEqual(h01["control"]["effective_unique_views"], 100)
        self.assertEqual(h01["control"]["synthetic_view_offset"], 1)
        self.assertEqual(h10["treatment"]["unique_views"], 101)
        self.assertEqual(h10["treatment"]["effective_unique_views"], 100)
        self.assertEqual(h10["treatment"]["synthetic_view_offset"], 1)

    def test_reports_only_aggregate_metrics(self) -> None:
        report = build_report(validate_arm_rows(fixture_rows()))
        markdown = render_markdown(report)
        encoded = json.dumps(report)
        self.assertFalse(report["privacy"]["contains_visitor_ids"])
        self.assertFalse(report["privacy"]["contains_raw_events"])
        self.assertNotIn("f0000000", encoded)
        for hypothesis in report["hypotheses"]:
            self.assertNotIn("visitor_id", hypothesis["control"])
            self.assertNotIn("visitor_id", hypothesis["treatment"])
        self.assertIn("H01", markdown)
        self.assertIn("H10", markdown)
        hypothesis_rows = [
            line
            for line in markdown.splitlines()
            if line.startswith("| H") and line[3:5].isdigit()
        ]
        self.assertEqual(len(hypothesis_rows), 10)

    def test_reports_aggregate_signup_handoff_without_pii(self) -> None:
        rows = fixture_rows()
        rows[0]["first_event_at"] = "2026-07-22T01:00:00Z"
        rows[-1]["last_event_at"] = "2026-08-19T02:00:00+00:00"
        arms = validate_arm_rows(rows)
        window = experiment_observation_window(arms)
        counts = summarize_funnel_rows(
            [
                {
                    "date": "2026-08-18",
                    "source_details": {
                        "funnel_trial_run": 3,
                        "funnel_save_cta": 2,
                        "funnel_magic_link_attempt": 3,
                        "funnel_magic_link_send": 2,
                        "funnel_magic_link_fail_delivery_config": 1,
                        "funnel_google_oauth_start": 1,
                        "funnel_google_oauth_fail_redirect": 1,
                        "funnel_inbox_open": 1,
                        "unrelated_event": 99,
                    },
                },
                {
                    "date": "2026-08-19",
                    "source_details": {"funnel_trial_run": 1},
                },
            ]
        )

        report = build_report(
            arms,
            funnel_counts=counts,
            funnel_observation_window=window,
        )
        markdown = render_markdown(report)

        self.assertEqual(window, ("2026-07-22", "2026-08-19"))
        self.assertEqual(report["funnel_diagnostics"]["trial_runs"], 4)
        self.assertEqual(report["funnel_diagnostics"]["magic_link_attempts"], 3)
        self.assertEqual(report["funnel_diagnostics"]["magic_link_sends"], 2)
        self.assertEqual(
            report["funnel_diagnostics"]["magic_link_failure_total"], 1
        )
        self.assertEqual(report["funnel_diagnostics"]["google_oauth_starts"], 1)
        self.assertEqual(
            report["funnel_diagnostics"]["google_oauth_failure_total"], 1
        )
        self.assertEqual(
            report["funnel_diagnostics"]["google_oauth_failures"][
                "redirect_configuration"
            ],
            1,
        )
        self.assertEqual(report["funnel_diagnostics"]["inbox_opens"], 1)
        self.assertEqual(
            report["funnel_diagnostics"]["recommended_next_action"],
            "repair_google_oauth_callback_failure",
        )
        self.assertIn("Magic Link attempts: 3", markdown)
        self.assertIn("Successful Magic Link sends: 2", markdown)
        self.assertIn("Categorized Google OAuth callback failures: 1", markdown)
        self.assertIn("Categorized Magic Link failures: 1", markdown)
        self.assertIn("Google OAuth starts: 1", markdown)
        self.assertIn("Inbox opens: 1", markdown)
        self.assertNotIn("unrelated_event", json.dumps(report))

    def test_rejects_invalid_aggregate_funnel_counts(self) -> None:
        with self.assertRaisesRegex(ReportContractError, "must be non-negative"):
            summarize_funnel_rows(
                [{"source_details": {"funnel_magic_link_send": -1}}]
            )

    @patch("landing_experiment_report.urllib.request.urlopen")
    def test_fetches_only_service_role_aggregate_view(self, urlopen) -> None:
        response = urlopen.return_value.__enter__.return_value
        response.read.return_value = json.dumps(fixture_rows()).encode("utf-8")

        rows = fetch_arm_rows(
            "https://example.supabase.co",
            "service-role-test-key",
        )

        self.assertEqual(len(rows), 20)
        request = urlopen.call_args.args[0]
        self.assertIn("landing_experiment_arm_stats", request.full_url)
        self.assertIn("unique_mobile_views", request.full_url)
        self.assertNotIn("landing_experiment_events?", request.full_url)
        self.assertEqual(
            request.get_header("Authorization"),
            "Bearer service-role-test-key",
        )

    @patch("landing_experiment_report.urllib.request.urlopen")
    def test_fetches_only_aggregate_signup_handoff_rows(self, urlopen) -> None:
        response = urlopen.return_value.__enter__.return_value
        response.read.return_value = json.dumps(
            [{"date": "2026-08-19", "source_details": {}}]
        ).encode("utf-8")

        rows = fetch_funnel_rows(
            "https://example.supabase.co",
            "service-role-test-key",
            start_date="2026-07-22",
            end_date="2026-08-19",
        )

        self.assertEqual(len(rows), 1)
        request = urlopen.call_args.args[0]
        self.assertIn("app_analytics", request.full_url)
        self.assertIn("source_details", request.full_url)
        self.assertIn("gte.2026-07-22", request.full_url)
        self.assertIn("lte.2026-08-19", request.full_url)
        self.assertNotIn("visitor", request.full_url)
        self.assertEqual(
            request.get_header("Authorization"),
            "Bearer service-role-test-key",
        )

    def test_workflow_never_exposes_service_role_to_pull_requests(self) -> None:
        workflow = (
            REPO_ROOT / ".github" / "workflows" / "landing-experiment-report.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("SUPABASE_SERVICE_ROLE_KEY", workflow)
        self.assertNotIn("pull_request:", workflow)


if __name__ == "__main__":
    unittest.main()
