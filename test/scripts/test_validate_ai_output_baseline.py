#!/usr/bin/env python3
"""Offline unit tests for scripts/validate_ai_output_baseline.py (#2657)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import validate_ai_output_baseline as mod  # noqa: E402


class ValidateAiOutputBaselineTest(unittest.TestCase):
    def test_default_baseline_suite_passes_with_zero_anomalies(self) -> None:
        report = mod.evaluate_baseline_suite()
        self.assertEqual(report["cases_total"], 5)
        self.assertEqual(report["cases_matched"], 5)
        self.assertFalse(report["anomaly_detected"])
        self.assertEqual(report["status"], "ok")

    def test_emergent_regression_flags_anomaly(self) -> None:
        cases = (
            mod.BaselineCase(
                case_id="regressed-json",
                prompt="JSONを返してください。",
                candidate_output='{"summary": "only_one_field"}',
                format_contract="json_object",
                expected_decision="passed",
                required_fields=("summary", "confidence"),
            ),
        )
        report = mod.evaluate_baseline_suite(cases=cases)
        self.assertTrue(report["anomaly_detected"])
        self.assertEqual(report["status"], "anomaly")
        self.assertEqual(report["cases_matched"], 0)
        self.assertEqual(report["results"][0]["actual_decision"], "blocked")

    def test_pii_and_banned_term_masking_protects_audit_logs(self) -> None:
        mail = "@".join(["audit", "example.org"])
        prompt = f"連絡先 {mail} の報告を作成"
        raw = f"## 結論\n{mail} に TODO_PLACEHOLDER を送付します。\n\n## 根拠\n手順書どおり。"
        res = mod.validate_output(raw, format_contract="markdown_sections")
        self.assertEqual(res.decision, "remediated")
        self.assertTrue(res.allowed)
        self.assertNotIn(mail, res.remediated_output)
        self.assertNotIn("TODO_PLACEHOLDER", res.remediated_output)

        log = mod.build_masked_log_entry(prompt, raw, res)
        self.assertNotIn(mail, str(log["prompt_excerpt"]))
        self.assertNotIn(mail, str(log["original_output_excerpt"]))
        self.assertIn("***", str(log["remediated_output_excerpt"]))

    def test_custom_banned_terms_and_concise_truncation(self) -> None:
        res = mod.validate_output(
            "秘密の内部語句を含むサマリー" + ("X" * 90),
            format_contract="concise_summary",
            banned_terms=("秘密の内部語句",),
            max_length=45,
        )
        self.assertEqual(res.decision, "remediated")
        self.assertTrue(res.allowed)
        self.assertNotIn("秘密の内部語句", res.remediated_output)
        self.assertLessEqual(len(res.remediated_output), 45)
        self.assertTrue(res.remediated_output.endswith("..."))

    def test_pinned_https_rejects_ssrf_and_handles_redirects_and_errors(self) -> None:
        with self.assertRaises(ValueError):
            mod.validate_and_resolve_https_url("http://example.com/hook")

        for private_ip in ("127.0.0.1", "10.0.0.5", "100.64.1.10", "::ffff:127.0.0.1"):
            fake_info = [(2, 1, 6, "", (private_ip, 443))]
            with mock.patch("validate_ai_output_baseline.socket.getaddrinfo", return_value=fake_info):
                with self.assertRaises(ValueError):
                    mod.validate_and_resolve_https_url("https://hooks.example.com/audit?sig=probe123")

        class _FakeResp:
            def __init__(self, status: int, body: str) -> None:
                self.status = status
                self._body = body.encode("utf-8")

            def read(self) -> bytes:
                return self._body

        public_info = [(2, 1, 6, "", ("93.184.216.34", 443))]
        with mock.patch("validate_ai_output_baseline.socket.getaddrinfo", return_value=public_info):
            with mock.patch("validate_ai_output_baseline._PinnedHTTPSConnection") as conn_cls:
                conn_inst = conn_cls.return_value
                conn_inst.getresponse.return_value = _FakeResp(302, "")
                with self.assertRaises(RuntimeError) as ctx302:
                    mod.post_json_pinned_https(
                        "https://hooks.example.com/audit?sig=probe123",
                        {"ok": True},
                    )
                self.assertNotIn("probe123", str(ctx302.exception))

                conn_inst.getresponse.return_value = _FakeResp(500, "err")
                with self.assertRaises(RuntimeError) as ctx500:
                    mod.post_json_pinned_https(
                        "https://hooks.example.com/audit?sig=probe123",
                        {"ok": True},
                    )
                self.assertNotIn("probe123", str(ctx500.exception))

    def test_cli_self_test_and_dry_run_outputs(self) -> None:
        self.assertEqual(mod.main(["--self-test"]), 0)
        with tempfile.TemporaryDirectory() as tmp:
            json_path = Path(tmp) / "report.json"
            md_path = Path(tmp) / "report.md"
            gh_path = Path(tmp) / "gh_out.txt"
            rc = mod.main(
                [
                    "--dry-run",
                    "--json-out",
                    str(json_path),
                    "--markdown-out",
                    str(md_path),
                    "--github-output",
                    str(gh_path),
                ]
            )
            self.assertEqual(rc, 0)
            loaded = json.loads(json_path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["status"], "ok")
            self.assertIn("anomaly_detected=false", gh_path.read_text(encoding="utf-8"))
            self.assertIn("Mode: `dry-run`", md_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
