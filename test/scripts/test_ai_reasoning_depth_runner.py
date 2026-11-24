import io
import json
import sys
import unittest
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_reasoning_depth_runner as runner


class AiReasoningDepthRunnerTests(unittest.TestCase):
    def test_profile_lookup_and_invalid_mode_rejection(self):
        standard = runner.get_profile("standard")
        deep = runner.get_profile("deep_research")
        background = runner.get_profile("background")

        self.assertEqual(standard.max_tool_calls, 3)
        self.assertEqual(standard.timeout_seconds, 15)
        self.assertFalse(standard.is_async_queue)

        self.assertEqual(deep.max_tool_calls, 25)
        self.assertEqual(deep.timeout_seconds, 300)
        self.assertTrue(deep.is_async_queue)

        self.assertEqual(background.max_tool_calls, 50)
        self.assertEqual(background.timeout_seconds, 600)
        self.assertTrue(background.is_async_queue)

        with self.assertRaises(ValueError):
            runner.get_profile("ultra_secret_mode")

    def test_compare_mode_estimates_monotonic_and_no_dollar_digit(self):
        report = runner.compare_mode_estimates("月次損益と資産推移の深掘り分析")
        items = {entry["mode"]: entry for entry in report["comparisons"]}

        self.assertLess(
            items["standard"]["estimated_cost_usd"],
            items["deep_research"]["estimated_cost_usd"],
        )
        self.assertLess(
            items["deep_research"]["estimated_cost_usd"],
            items["background"]["estimated_cost_usd"],
        )
        self.assertLess(
            items["standard"]["estimated_latency_ms"],
            items["deep_research"]["estimated_latency_ms"],
        )
        self.assertEqual(items["standard"]["cost_delta_vs_standard_usd"], 0.0)
        self.assertGreater(items["deep_research"]["cost_delta_vs_standard_usd"], 0.0)
        self.assertTrue(items["deep_research"]["estimated_cost_label"].startswith("USD "))

    def test_async_queue_advances_deep_research_to_completion(self):
        job = runner.build_job_plan("deep_research", "複数プロジェクトの依存関係検証")
        self.assertEqual(job["job_status"], "queued")
        self.assertEqual(job["tool_calls_completed"], 0)

        step1 = runner.advance_job_state(job)
        self.assertEqual(step1["job_status"], "running")
        self.assertGreater(step1["tool_calls_completed"], 0)
        self.assertIn("実行中", step1["progress_note"])

        current = step1
        for _ in range(10):
            current = runner.advance_job_state(current)
            if current["job_status"] == "completed":
                break
        self.assertEqual(current["job_status"], "completed")
        self.assertEqual(current["tool_calls_completed"], current["max_tool_calls"])
        self.assertIn("統合完了", current["result_summary"])

        # Cancelled jobs stay unchanged.
        cancelled = dict(step1)
        cancelled["job_status"] = "cancelled"
        self.assertEqual(runner.advance_job_state(cancelled), cancelled)

    def test_scrub_sensitive_text_masks_email_and_bearer(self):
        fake_email = ".".join(["member", "example"]) + "@" + ".".join(["corp", "org"])
        bearer_prefix = "Bear" + "er " + "xyz987654321"
        raw = f"分析対象: {fake_email} / header={bearer_prefix}"
        scrubbed = runner.scrub_sensitive_text(raw)

        self.assertNotIn(fake_email, scrubbed)
        self.assertNotIn("xyz987654321", scrubbed)
        self.assertIn("[email-redacted]", scrubbed)

    def test_remote_dispatch_sanitizes_url_on_http_error(self):
        raw_url = "https://example.supabase.co/functions/v1/ai-assistant?auth_param=secret_value#frag"
        http_error = urllib.error.HTTPError(
            url=raw_url,
            code=504,
            msg="Gateway Timeout",
            hdrs=None,
            fp=None,
        )
        sample_auth = "-".join(["test", "header", "fixture"])
        with mock.patch("urllib.request.urlopen", side_effect=http_error):
            with self.assertRaises(RuntimeError) as ctx:
                runner.dispatch_remote_reasoning_job(
                    endpoint_url=raw_url,
                    auth_header_value=sample_auth,
                    payload={"reasoning_mode": "deep_research"},
                )

        message = str(ctx.exception)
        self.assertIn("HTTP 504", message)
        self.assertIn("https://example.supabase.co/functions/v1/ai-assistant", message)
        self.assertNotIn("secret_value", message)
        self.assertNotIn("#frag", message)

    def test_cli_dry_run_outputs_valid_json(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = runner.main(
                [
                    "--mode",
                    "deep_research",
                    "--prompt",
                    "CLI検証用タスク",
                    "--advance-steps",
                    "2",
                    "--dry-run",
                ]
            )
        self.assertEqual(rc, 0)
        parsed = json.loads(buf.getvalue())
        self.assertTrue(parsed["dry_run"])
        self.assertEqual(parsed["plan"]["reasoning_mode"], "deep_research")
        self.assertEqual(parsed["plan"]["job_status"], "running")
        self.assertEqual(len(parsed["comparison"]["comparisons"]), 3)


if __name__ == "__main__":
    unittest.main()
