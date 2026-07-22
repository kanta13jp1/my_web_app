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
    parse_synthetic_offsets,
    render_markdown,
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
                    "first_event_at": None,
                    "last_event_at": None,
                }
            )
    return rows


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
        arms = validate_arm_rows(
            fixture_rows(views=99, control_submits=1, treatment_submits=20)
        )
        report = build_report(arms)
        self.assertTrue(report["gates"]["global_signup_submit_gate_ready"])
        self.assertTrue(
            all(
                hypothesis["decision"] == "insufficient_data"
                for hypothesis in report["hypotheses"]
            )
        )

    def test_declares_treatment_only_with_lift_and_separated_intervals(self) -> None:
        arms = validate_arm_rows(
            fixture_rows(views=100, control_submits=10, treatment_submits=30)
        )
        report = build_report(arms)
        first = report["hypotheses"][0]
        self.assertEqual(first["decision"], "treatment_wins")
        self.assertAlmostEqual(first["relative_signup_submit_lift"], 2.0)

    def test_synthetic_offset_removes_qa_view_from_effective_sample(self) -> None:
        rows = fixture_rows(views=100, control_submits=10, treatment_submits=10)
        for row in rows:
            if row["hypothesis_id"] == "h10" and row["variant"] == "treatment":
                row["unique_views"] = 101
        arms = validate_arm_rows(rows)
        offsets = parse_synthetic_offsets(["h10:treatment:1"])
        report = build_report(arms, synthetic_offsets=offsets)
        h10 = report["hypotheses"][-1]
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
        self.assertNotIn("landing_experiment_events?", request.full_url)
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
