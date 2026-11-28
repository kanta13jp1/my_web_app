#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import json
import sys
import unittest
from pathlib import Path
from typing import Any


SCRIPTS_DIR = Path(__file__).resolve().parents[2] / ".github" / "scripts"


def _load_script(name: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS_DIR / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


competitor_discover = _load_script("competitor_discover")
competitor_stage = _load_script("competitor_stage")


class _FakeHttpResponse:
    def __init__(self, status: int, body: str) -> None:
        self.status = status
        self._body = body.encode("utf-8")

    def read(self) -> bytes:
        return self._body

    def __enter__(self) -> "_FakeHttpResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None


class CompetitorDiscoveryLoggingTests(unittest.TestCase):
    def test_query_gemini_with_log_captures_query_and_sanitizes_errors(self) -> None:
        fake_key = "test-gem-placeholder-value"
        captured_reqs: list[tuple[str, dict[str, Any]]] = []

        def ok_opener(req: Any, timeout: int = 30) -> _FakeHttpResponse:
            captured_reqs.append((req.full_url, json.loads(req.data.decode("utf-8"))))
            payload = {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps([
                                        {
                                            "id": "notion-competitor",
                                            "display_name": "Notion Rival",
                                            "category": "productivity",
                                        }
                                    ])
                                }
                            ]
                        }
                    }
                ]
            }
            return _FakeHttpResponse(200, json.dumps(payload))

        candidates, qlog = competitor_discover.query_gemini_with_log(
            fake_key,
            "productivity",
            3,
            "Evernote, Notion",
            "2026-11-24",
            opener=ok_opener,
        )
        self.assertEqual(len(candidates), 1)
        self.assertEqual(qlog["category"], "productivity")
        self.assertEqual(qlog["http_status"], 200)
        self.assertEqual(qlog["candidate_count"], 1)
        self.assertIsNone(qlog["error"])
        self.assertNotIn(fake_key, qlog["prompt_preview"])
        self.assertEqual(len(captured_reqs), 1)
        self.assertIn("gemini-4-hydrogen:generateContent", captured_reqs[0][0])
        gen_cfg = captured_reqs[0][1]["generationConfig"]
        self.assertEqual(gen_cfg["thinkingConfig"]["thinkingLevel"], "LOW")
        self.assertEqual(gen_cfg["maxOutputTokens"], 65536)
        self.assertNotIn("temperature", gen_cfg)

        def fail_opener(_req: Any, timeout: int = 30) -> _FakeHttpResponse:
            raise RuntimeError(
                f"GET https://generativelanguage.googleapis.com/v1beta?key={fake_key} timed out"
            )

        empty, fail_log = competitor_discover.query_gemini_with_log(
            fake_key,
            "fintech",
            3,
            "MoneyForward",
            "2026-11-24",
            opener=fail_opener,
        )
        self.assertEqual(empty, [])
        self.assertIsNotNone(fail_log["error"])
        self.assertNotIn(fake_key, str(fail_log["error"]))
        self.assertIn("key=***", str(fail_log["error"]))

    def test_build_discovery_log_payload_and_persist(self) -> None:
        zero_payload = competitor_stage.build_discovery_log_payload(
            discovery_log={
                "discovery_week": "2026-48",
                "categories": ["productivity"],
                "queries_json": [{"category": "productivity", "candidate_count": 0}],
                "error_count": 1,
                "error_logs": ["[productivity] timeout"],
            },
            week_str="2026-48",
            run_id="999111",
            total_candidates=0,
            staged_count=0,
            skip_count=0,
            stage_error_count=0,
            stage_error_logs=[],
        )
        self.assertTrue(zero_payload["zero_result_alert_triggered"])
        self.assertIn("0 candidates", zero_payload["alert_summary"])
        self.assertEqual(zero_payload["error_count"], 1)

        posted: list[tuple[str, dict[str, Any]]] = []

        def mock_post(req: Any, timeout: int = 20) -> _FakeHttpResponse:
            posted.append((req.full_url, json.loads(req.data.decode("utf-8"))))
            return _FakeHttpResponse(201, "")

        saved = competitor_stage.persist_discovery_log(
            supabase_url="https://example.supabase.co",
            service_key="srv-role-test",
            log_payload=zero_payload,
            opener=mock_post,
        )
        self.assertTrue(saved)
        self.assertEqual(len(posted), 1)
        self.assertTrue(posted[0][0].endswith("/rest/v1/competitor_discovery_logs"))
        self.assertEqual(posted[0][1]["zero_result_alert_triggered"], True)


if __name__ == "__main__":
    unittest.main()
