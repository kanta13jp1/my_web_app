#!/usr/bin/env python3
"""Tests for scripts/dynamic_llm_router.py, config/llm_routing_rules.json, and workflow."""

from __future__ import annotations

import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import dynamic_llm_router as router  # noqa: E402


class DynamicLlmRouterTests(unittest.TestCase):
    def test_canonical_config_validates_and_matches_effort_router_ts(self) -> None:
        config = router.load_routing_config(ROOT / "config" / "llm_routing_rules.json")
        self.assertEqual(router.validate_routing_config(config), [])
        sync_errors = router.check_effort_router_sync(
            config,
            ROOT / "supabase" / "functions" / "_shared" / "effort_router.ts",
        )
        self.assertEqual(sync_errors, [])

    def test_invalid_config_rejected(self) -> None:
        config = router.load_routing_config(ROOT / "config" / "llm_routing_rules.json")
        broken = copy.deepcopy(config)
        broken["tiers"]["trivial"]["max_cost_per_call_usd"] = 0
        with self.assertRaises(ValueError):
            router.validate_routing_config(broken)

    def test_routes_trivial_vs_complex_and_applies_budget_and_circuit_breaker(self) -> None:
        config = router.load_routing_config(ROOT / "config" / "llm_routing_rules.json")

        trivial = router.route_task(config, category="routine_ops")
        self.assertEqual(trivial.tier, "trivial")
        self.assertEqual(trivial.model, "claude-haiku-4-5")
        self.assertFalse(trivial.is_frontier)

        standard = router.route_task(config, category="summarization")
        self.assertEqual(standard.tier, "standard")
        self.assertEqual(standard.model, "gpt-5.4-mini")

        critical = router.route_task(
            config,
            category="architecture_design",
            request_meta={"requires_deep_reasoning": True},
        )
        self.assertEqual(critical.tier, "critical")
        self.assertEqual(critical.model, "claude-opus-4-7")
        self.assertTrue(critical.is_frontier)

        downgraded = router.route_task(
            config,
            category="deep_reasoning",
            remaining_budget_usd=2.5,
            unhealthy_models=("claude-sonnet-4-6",),
        )
        self.assertEqual(downgraded.tier, "complex")
        self.assertTrue(downgraded.downgraded_by_budget)
        self.assertFalse(downgraded.budget_exhausted)
        self.assertEqual(downgraded.model, "gpt-5.4")

        exhausted = router.route_task(
            config,
            category="deep_reasoning",
            remaining_budget_usd=0.0,
        )
        self.assertEqual(exhausted.tier, "trivial")
        self.assertTrue(exhausted.budget_exhausted)

    def test_analyzes_per_model_calls_and_frontier_cost_separation(self) -> None:
        config = router.load_routing_config(ROOT / "config" / "llm_routing_rules.json")
        events = [
            {
                "event_id": "e1",
                "provider": "anthropic",
                "model": "claude-haiku-4-5",
                "task_type": "chat",
                "status": "success",
                "estimated_cost_usd": 0.005,
                "tier": "trivial",
            },
            {
                "event_id": "e2",
                "provider": "anthropic",
                "model": "claude-haiku-4-5",
                "task_type": "search",
                "status": "success",
                "estimated_cost_usd": 0.005,
                "tier": "trivial",
            },
            {
                "event_id": "e3",
                "provider": "anthropic",
                "model": "claude-opus-4-7",
                "task_type": "architecture_design",
                "status": "success",
                "estimated_cost_usd": 0.090,
                "tier": "critical",
            },
        ]
        summary = router.analyze_routing_telemetry(events, config)
        by_model = {(row["provider"], row["model"]): row for row in summary["by_model"]}
        self.assertEqual(by_model[("anthropic", "claude-haiku-4-5")]["call_count"], 2)
        self.assertAlmostEqual(by_model[("anthropic", "claude-haiku-4-5")]["estimated_cost_usd"], 0.01)
        self.assertEqual(by_model[("anthropic", "claude-opus-4-7")]["call_count"], 1)
        self.assertAlmostEqual(by_model[("anthropic", "claude-opus-4-7")]["estimated_cost_usd"], 0.09)
        sep = summary["cost_separation"]
        self.assertEqual(sep["frontier_calls"], 1)
        self.assertEqual(sep["non_frontier_calls"], 2)
        self.assertAlmostEqual(sep["frontier_cost_share"], 0.9)
        self.assertTrue(
            any(a["reason"] == "frontier_cost_share_threshold" for a in summary["alerts"])
        )

    def test_redacts_standalone_tokens_and_writes_cli_reports(self) -> None:
        fake_ghp = "ghp_" + "1234567890abcdef"
        fake_sk = "sk-" + "proj-" + "abcdef1234567890"
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            req_file = root / "req.json"
            req_file.write_text(
                json.dumps(
                    {
                        "category": "code_review",
                        "description": f"Audit PR diff with {fake_ghp} and {fake_sk}",
                    }
                ),
                encoding="utf-8",
            )
            json_out = root / "out.json"
            md_out = root / "out.md"
            gh_out = root / "gh_output.txt"
            sample_telemetry = ROOT / "docs" / "ai-bench" / "results" / "model_usage_events.sample.jsonl"

            rc = router.main(
                [
                    "--validate-config",
                    "--route-json",
                    str(req_file),
                    "--telemetry-input",
                    str(sample_telemetry),
                    "--dry-run",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(rc, 0)
            json_text = json_out.read_text(encoding="utf-8")
            md_text = md_out.read_text(encoding="utf-8")
            self.assertNotIn(fake_ghp, json_text)
            self.assertNotIn(fake_sk, json_text)
            self.assertNotIn(fake_ghp, md_text)
            self.assertGreaterEqual(json.loads(json_text)["decision"]["redaction_count"], 2)
            self.assertIn("selected_tier=complex", gh_out.read_text(encoding="utf-8"))

        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(router.main(["--self-test"]), 0)

    def test_workflow_contract_least_privilege_and_sha_pins(self) -> None:
        wf = ROOT / ".github" / "workflows" / "dynamic-llm-router.yml"
        self.assertTrue(wf.is_file())
        content = wf.read_text(encoding="utf-8")
        self.assertIn("permissions: {}", content)
        self.assertIn("contents: read", content)
        for forbidden in (
            "SUPABASE_SERVICE_ROLE_KEY",
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            "CLAUDE_CODE_OAUTH_TOKEN",
        ):
            self.assertNotIn(forbidden, content)


if __name__ == "__main__":
    unittest.main()
