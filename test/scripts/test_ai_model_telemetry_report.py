import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_model_telemetry_report


def sample_events() -> list[dict]:
    return [
        {
            "event_id": "evt-1",
            "occurred_at": "2026-05-18T00:00:00Z",
            "provider": "openai",
            "model": "gpt-5.5",
            "task_type": "asset_report_summary",
            "feature": "monthly_asset_report",
            "status": "success",
            "latency_ms": 1200,
            "estimated_cost_usd": 0.04,
            "input_tokens": 1200,
            "output_tokens": 300,
            "thinking_tokens": 100,
            "quality_score": 0.92,
        },
        {
            "event_id": "evt-2",
            "occurred_at": "2026-05-18T00:01:00Z",
            "provider": "openai",
            "model": "gpt-5.5",
            "task_type": "asset_report_summary",
            "feature": "monthly_asset_report",
            "status": "timeout",
            "latency_ms": 35000,
            "estimated_cost_usd": 0.03,
            "input_tokens": 900,
            "output_tokens": 0,
            "thinking_tokens": 50,
            "quality_score": 0.0,
        },
        {
            "event_id": "evt-3",
            "occurred_at": "2026-05-18T00:02:00Z",
            "provider": "anthropic",
            "model": "claude-opus-4-7",
            "task_type": "payment_risk_explanation",
            "feature": "payment_reminder",
            "status": "success",
            "latency_ms": 2200,
            "estimated_cost_usd": 0.06,
            "input_tokens": 1000,
            "output_tokens": 450,
            "thinking_tokens": 200,
            "quality_score": 0.88,
        },
    ]


class AiModelTelemetryReportTest(unittest.TestCase):
    def test_report_groups_cost_latency_and_failure_rate(self) -> None:
        report = ai_model_telemetry_report.build_report(
            sample_events(),
            failure_rate_alert=0.4,
            min_events_for_failure_alert=2,
            latency_alert_ms=30000,
        )

        self.assertFalse(report["live_provider_calls"])
        self.assertEqual(report["event_count"], 3)
        groups = {
            (group["provider"], group["model"], group["task_type"]): group
            for group in report["groups"]
        }
        openai = groups[("openai", "gpt-5.5", "asset_report_summary")]
        self.assertEqual(openai["event_count"], 2)
        self.assertEqual(openai["failure_rate"], 0.5)
        self.assertAlmostEqual(openai["estimated_cost_usd"], 0.07)
        self.assertEqual(openai["thinking_tokens"], 150)
        self.assertTrue(
            any(alert["reason"] == "failure_rate_threshold" for alert in report["alerts"])
        )
        self.assertTrue(any(alert["reason"] == "latency_threshold" for alert in report["alerts"]))

    def test_sensitive_payload_keys_are_blockers(self) -> None:
        events = sample_events()
        events.append(
            {
                "provider": "openai",
                "model": "gpt-5.5",
                "task_type": "unsafe",
                "status": "success",
                "metadata": {"account_number": "1234"},
            }
        )

        report = ai_model_telemetry_report.build_report(events)

        blockers = [alert for alert in report["alerts"] if alert["severity"] == "blocker"]
        self.assertEqual(len(blockers), 1)
        self.assertIn("metadata.account_number", blockers[0]["message"])

    def test_cli_writes_json_and_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            input_path = root / "events.jsonl"
            out_json = root / "summary.json"
            out_md = root / "summary.md"
            input_path.write_text(
                "\n".join(json.dumps(event) for event in sample_events()) + "\n",
                encoding="utf-8",
            )

            self.assertEqual(
                ai_model_telemetry_report.main(
                    [
                        "--input",
                        str(input_path),
                        "--output-json",
                        str(out_json),
                        "--output-md",
                        str(out_md),
                        "--failure-rate-alert",
                        "0.4",
                        "--min-events-for-failure-alert",
                        "2",
                    ]
                ),
                0,
            )

            summary = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(summary["issue"], "#2522")
            markdown = out_md.read_text(encoding="utf-8")
            self.assertIn("AI Model Telemetry Monthly Review", markdown)
            self.assertIn("fixed strongest model", markdown)


if __name__ == "__main__":
    unittest.main()
