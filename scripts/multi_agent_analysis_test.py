#!/usr/bin/env python3
"""Offline unit tests for scripts/multi_agent_analysis.py (#2641)."""

from __future__ import annotations

import io
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock
from urllib import error as urllib_error

sys.path.insert(0, str(Path(__file__).resolve().parent))
import multi_agent_analysis as maa


class MultiAgentAnalysisTests(unittest.TestCase):
    def test_sequential_three_agent_handoff_and_reasoning_trace(self) -> None:
        orchestrator = maa.SequentialMultiAgentOrchestrator()
        result = orchestrator.run(
            {
                "topic": "ポートフォリオ配分およびキャッシュフロー分析",
                "actor_id": "raw-user-id-42",
                "observations": [
                    {"label": "Q1", "value": 100.0, "unit": "USD", "confidence": 0.95},
                    {"label": "Q2", "value": 115.0, "unit": "USD", "confidence": 0.92},
                    {"label": "Q3", "value": 155.0, "unit": "USD", "confidence": 0.89},
                ],
            }
        )

        self.assertEqual(result["collector_output"]["stage"], "data_collection")
        self.assertEqual(result["calculator_output"]["stage"], "metric_calculation")
        self.assertEqual(result["synthesizer_output"]["stage"], "synthesis_advisory")

        trace = result["reasoning_trace"]
        self.assertEqual(len(trace), 3)
        self.assertEqual(
            [step["agent_name"] for step in trace],
            ["DataCollectorAgent", "MetricCalculatorAgent", "SynthesisAdvisorAgent"],
        )

        metrics = result["calculator_output"]["payload"]["metrics"]
        self.assertEqual(metrics["observation_count"], 3)
        self.assertAlmostEqual(metrics["numeric_total"], 370.0)
        self.assertAlmostEqual(metrics["pct_change"], 55.0)
        self.assertTrue(result["requires_human_confirmation"])
        self.assertEqual(result["human_review_status"], "pending_human_review")
        self.assertIn("Human-in-the-Loop", result["advisory_notice"])
        self.assertTrue(result["synthesizer_output"]["payload"]["requires_human_confirmation"])

    def test_rejects_invalid_intermediate_json_handoffs(self) -> None:
        calculator = maa.MetricCalculatorAgent()
        with self.assertRaises(ValueError):
            calculator.run({"stage": "wrong_stage", "payload": {"topic": "x", "observations": [{"label": "a", "value": 1}]}})
        with self.assertRaises(ValueError):
            calculator.run({"stage": "data_collection", "payload": {"topic": "x", "observations": [{"label": "a", "value": float("nan")}]}})

        synthesizer = maa.SynthesisAdvisorAgent()
        with self.assertRaises(ValueError):
            synthesizer.run({"stage": "data_collection", "payload": {"topic": "x", "metrics": {}}})
        with self.assertRaises(ValueError):
            synthesizer.run({"stage": "metric_calculation", "payload": {"topic": "x", "metrics": {"observation_count": 1}}})

    def test_scrubs_pii_and_secrets_before_stage_handoff(self) -> None:
        orchestrator = maa.SequentialMultiAgentOrchestrator()
        fake_email = "alice.operator" + "@" + "example.org"
        fake_phone = "090-" + "1234-" + "5678"
        fake_bearer = "Bearer " + "sample_" + "credential_xyz123"
        fake_jwt = "eyJ" + "headerSample1" + "." + "payloadSample2" + "." + "sigSample345"
        fake_tok = "sk-" + "proj-" + "sampleTokenValue9876"

        result = orchestrator.run(
            {
                "topic": f"調査 {fake_email}",
                "actor_id": "sensitive-user-999",
                "observations": [
                    {
                        "label": "コスト記録",
                        "value": 42.0,
                        "notes": f"連絡先 {fake_phone} / {fake_bearer} / {fake_jwt} / {fake_tok}",
                    }
                ],
            }
        )
        serialized = json.dumps(result, ensure_ascii=False)
        for leak in (fake_email, fake_phone, fake_bearer, fake_jwt, fake_tok, "sensitive-user-999"):
            self.assertNotIn(leak, serialized)
        self.assertGreaterEqual(result["collector_output"]["payload"]["sanitized_redaction_count"], 5)
        self.assertTrue(result["collector_output"]["payload"]["actor_pseudonym"].startswith("usr_"))

    def test_llm_http_error_sanitizes_query_and_raises_runtime_error(self) -> None:
        calculator_out = maa.MetricCalculatorAgent().run(
            maa.DataCollectorAgent().run(maa.build_default_sample_input("HTTP エラー検証"))
        )
        synthesizer = maa.SynthesisAdvisorAgent()
        endpoint = "https://api.example.invalid/v1/chat/completions?key=sensitive_query_val"
        http_err = urllib_error.HTTPError(
            url=endpoint,
            code=429,
            msg="Too Many Requests",
            hdrs=None,  # type: ignore[arg-type]
            fp=io.BytesIO(b"{}"),
        )
        env_var = "OPENAI_" + "API_KEY"
        with mock.patch.dict(os.environ, {env_var: "stub", "OPENAI_API_BASE_URL": endpoint}):
            with mock.patch("multi_agent_analysis.urllib_request.urlopen", side_effect=http_err):
                with self.assertRaises(RuntimeError) as ctx:
                    synthesizer.run(calculator_out, use_llm=True)
        self.assertIn("429", str(ctx.exception))
        self.assertNotIn("sensitive_query_val", str(ctx.exception))
        self.assertNotIn("?", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
