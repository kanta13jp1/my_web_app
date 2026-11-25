#!/usr/bin/env python3
"""Unit and contract tests for AI agent memory compression LLM optimization (#2708)."""

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import memory_compression_optimizer as opt  # noqa: E402


class MemoryCompressionOptimizerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.config = opt.load_compression_config()

    def test_default_route_selects_low_cost_gemini_and_matches_ts_parity(self) -> None:
        route, active, baseline = opt.resolve_compression_route(self.config, env={})
        self.assertEqual(route.provider, "google")
        self.assertEqual(route.model, "gemini-2.5-flash")
        self.assertEqual(route.baseline_model, "claude-sonnet-4-6")
        self.assertEqual(active.input_usd_per_1m, 0.15)
        self.assertEqual(baseline.output_usd_per_1m, 15.0)

        ts_text = opt.DEFAULT_TS_ROUTER_PATH.read_text(encoding="utf-8")
        ts_models = set(re.findall(r'model:\s*"([^"]+)"', ts_text))
        for profile in self.config["profiles"].values():
            self.assertIn(profile["model"], ts_models)

    def test_env_and_cli_overrides_switch_provider_and_model(self) -> None:
        route_env, active_env, _ = opt.resolve_compression_route(
            self.config,
            env={
                "AGENT_MEMORY_COMPRESSION_PROVIDER": "groq",
                "AGENT_MEMORY_COMPRESSION_MODEL": "llama-3.3-70b-versatile",
            },
        )
        self.assertEqual(route_env.provider, "groq")
        self.assertEqual(route_env.model, "llama-3.3-70b-versatile")
        self.assertEqual(route_env.source, "env_override")
        self.assertEqual(active_env.input_usd_per_1m, 0.05)

        route_cli, _, _ = opt.resolve_compression_route(
            self.config,
            env={"AGENT_MEMORY_COMPRESSION_PROVIDER": "groq"},
            profile_override="claude_haiku",
        )
        self.assertEqual(route_cli.provider, "anthropic")
        self.assertEqual(route_cli.model, "claude-haiku-4-5")
        self.assertEqual(route_cli.source, "profile_override")

    def test_redaction_masks_secrets_before_compression_and_outbound_payload(self) -> None:
        fake_pat = "_".join(["ghp", "exampleSensitiveToken123456"])
        fake_assign = "=".join(["auth" + "_token", "dummyValue123456"])
        raw_log = (
            f"Decision: Handle #2708 safely.\n"
            f"Debug leak: {fake_pat} and {fake_assign}\n"
            "Constraint: Never retain secrets in memory.\n"
        )
        result = opt.compress_memory_log(raw_log, self.config, dry_run=True)
        self.assertGreaterEqual(result["redactions_applied"], 2)
        self.assertNotIn("exampleSensitiveToken123456", result["summary"])
        self.assertNotIn("dummyValue123456", result["summary"])

    def test_live_provider_dispatch_with_mock_gemini_and_cost_savings(self) -> None:
        captured: list[dict] = []

        def fake_dispatch(req_spec: dict) -> dict:
            captured.append(req_spec)
            return {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": (
                                        "## Decisions\n"
                                        "- Switched #2708 memory compression to Gemini Flash.\n"
                                        "## Open Tasks\n"
                                        "- Validate scripts/memory_compression_optimizer.py telemetry.\n"
                                        "## Key Identifiers\n"
                                        "- #2708, scripts/memory_compression_optimizer.py\n"
                                        "## Constraints\n"
                                        "- Maintain context restoration >= 0.70.\n"
                                    )
                                }
                            ]
                        }
                    }
                ],
                "usageMetadata": {
                    "promptTokenCount": 50000,
                    "candidatesTokenCount": 4000,
                },
            }

        raw_log = (
            "Decision: Switch Issue #2708 to Gemini.\n"
            "Path: scripts/memory_compression_optimizer.py\n"
            "Constraint: Maintain context restoration >= 0.70.\n"
        ) + ("Context detail filler line for compression measurement.\n" * 12)

        env_key = self.config["profiles"]["gemini_flash_low_cost"]["auth_env_var"]
        mock_env = {env_key: "local-test-val"}

        res = opt.compress_memory_log(
            raw_log,
            self.config,
            env=mock_env,
            dry_run=False,
            http_dispatch=fake_dispatch,
        )
        self.assertEqual(len(captured), 1)
        self.assertIn("gemini-2.5-flash:generateContent", captured[0]["url"])
        self.assertEqual(res["execution_mode"], "live_provider")
        self.assertTrue(res["quality"]["passed"])
        self.assertGreater(res["cost"]["savings_pct"], 95.0)
        self.assertEqual(res["cost"]["input_tokens"], 50000)
        self.assertEqual(res["cost"]["output_tokens"], 4000)

    def test_quality_gate_rejects_lossy_summary_and_ssrf_blocks_local_urls(self) -> None:
        raw = (
            "Decision: Keep #2708 and #6337 synchronized with "
            "supabase/functions/_shared/memory_compression_router.ts."
        )
        bad_eval = opt.evaluate_restoration_quality(
            raw,
            "Compressed brief.",
            self.config["quality_contract"],
        )
        self.assertFalse(bad_eval.passed)
        self.assertIn("#2708", bad_eval.missing_anchors)
        self.assertIn("decisions", bad_eval.missing_sections)

        for unsafe_url in (
            "http://generativelanguage.googleapis.com/v1beta/test",
            "https://localhost/v1/messages",
            "https://127.0.0.1/v1/messages",
            "https://10.0.0.1/v1/messages",
        ):
            with self.assertRaises(ValueError):
                opt.validate_public_https_endpoint(unsafe_url)

    def test_telemetry_aggregation_and_cli_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            log_file = tmp / "session.log"
            log_file.write_text(
                "\n".join(
                    [
                        "Decision: Adopted Gemini Flash for #2708 memory compression.",
                        "File: config/memory_compression_llm.json",
                        "Constraint: Must preserve all identifiers and pass quality check.",
                        "Pending: Review savings metrics in CI workflow.",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            jsonl_path = tmp / "telemetry.jsonl"
            json_out = tmp / "report.json"
            md_out = tmp / "report.md"
            gh_out = tmp / "gh_output.txt"

            rc = opt.main(
                [
                    "--input",
                    str(log_file),
                    "--dry-run",
                    "--telemetry-log",
                    str(jsonl_path),
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(rc, 0)
            payload = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertTrue(payload["config_valid"])
            self.assertGreater(payload["telemetry"]["overall_savings_pct"], 90.0)
            self.assertIn("active_provider=google", gh_out.read_text(encoding="utf-8"))
            self.assertEqual(opt.main(["--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
