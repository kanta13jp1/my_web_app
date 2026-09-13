import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_university_reliability_metrics as metrics


def event(name: str, timestamp: str = "2026-08-29T12:00:00Z") -> dict[str, str]:
    return {
        "event_name": name,
        "surface": "ai_university_content",
        "occurred_at": timestamp,
    }


class AiUniversityReliabilityMetricsTest(unittest.TestCase):
    def test_aggregates_directional_counts_and_ratios_without_thresholds(self) -> None:
        report = metrics.build_report(
            [
                event("content_fetch_failed"),
                event("fallback_shown"),
                event("retry_requested"),
                event("retry_succeeded"),
                event("retry_failed"),
            ]
        )
        self.assertTrue(report["valid"])
        self.assertEqual(report["ratios"]["fallbacks_per_fetch_failure"], 1.0)
        self.assertEqual(report["ratios"]["retry_success_rate"], 0.5)
        self.assertEqual(report["ratios"]["retry_outcomes_per_request"], 2.0)
        self.assertFalse(
            report["threshold_evaluation"]["automated_decision_allowed"]
        )
        self.assertEqual(report["threshold_evaluation"]["status"], "not_configured")

    def test_zero_denominators_remain_not_applicable(self) -> None:
        report = metrics.build_report([])
        self.assertTrue(report["valid"])
        self.assertIsNone(report["ratios"]["retry_success_rate"])
        self.assertEqual(report["data_quality_warnings"], [])

    def test_rejects_unknown_or_malformed_events(self) -> None:
        report = metrics.build_report(
            [event("unknown"), event("retry_failed", "not-a-time")]
        )
        self.assertFalse(report["valid"])
        self.assertEqual(
            [error["code"] for error in report["errors"]],
            ["unknown_event_name", "invalid_occurred_at"],
        )

    def test_records_and_enforces_requested_window(self) -> None:
        start = datetime(2026, 8, 1, tzinfo=timezone.utc)
        end = datetime(2026, 9, 1, tzinfo=timezone.utc)
        report = metrics.build_report(
            [event("retry_requested")],
            window_start_at=start,
            window_end_at=end,
        )
        self.assertTrue(report["valid"])
        self.assertEqual(report["requested_window_start_at"], start.isoformat())
        self.assertEqual(report["requested_window_end_at"], end.isoformat())

        outside = metrics.build_report(
            [event("retry_requested", "2026-09-01T00:00:00Z")],
            window_start_at=start,
            window_end_at=end,
        )
        self.assertFalse(outside["valid"])
        self.assertEqual(outside["errors"][0]["code"], "event_after_window")

    def test_content_range_exposes_truncated_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            headers = Path(tmp) / "headers.txt"
            headers.write_text("Content-Range: 0-0/2\n", encoding="utf-8")
            expected = metrics.expected_count_from_headers(headers)
            report = metrics.build_report([event("retry_requested")], expected_count=expected)
            self.assertEqual(expected, 2)
            self.assertTrue(report["input_truncated"])
            self.assertIn("input_truncated", report["data_quality_warnings"])

    def test_cli_writes_machine_and_human_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "events.json"
            output_json = root / "metrics.json"
            output_md = root / "metrics.md"
            source.write_text(json.dumps([event("retry_succeeded")]), encoding="utf-8")
            self.assertEqual(
                metrics.main(
                    [
                        str(source),
                        "--output-json",
                        str(output_json),
                        "--output-md",
                        str(output_md),
                    ]
                ),
                0,
            )
            self.assertEqual(
                json.loads(output_json.read_text(encoding="utf-8"))["valid_event_count"],
                1,
            )
            self.assertIn("no automated decision", output_md.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
