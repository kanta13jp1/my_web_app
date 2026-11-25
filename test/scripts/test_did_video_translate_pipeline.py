#!/usr/bin/env python3
"""Offline unit tests for scripts/did_video_translate_pipeline.py (#2660)."""

from __future__ import annotations

import json
import socket
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import did_video_translate_pipeline as pipeline  # noqa: E402


class DidVideoTranslatePipelineTest(unittest.TestCase):
    def test_bcp47_to_did_language_mapping_and_deduplication(self) -> None:
        codes, names = pipeline.normalize_target_languages(["ja", "en-US", "Spanish", "ja", "fr"])
        self.assertEqual(codes, ("ja", "en-us", "es", "fr"))
        self.assertEqual(names, ("Japanese", "English", "Spanish", "French"))

        with self.assertRaises(ValueError):
            pipeline.normalize_target_languages(["xx"])

    def test_fail_closed_duration_and_cost_caps(self) -> None:
        with self.assertRaises(pipeline.CapExceededError):
            pipeline.build_translation_plan(
                source_video_id="vid-over-dur",
                source_video_url="https://example.com/a.mp4",
                languages=["ja", "en"],
                duration_seconds=150,
                max_duration_cap_seconds=120,
                max_cost_cap_usd=50.0,
            )

        with self.assertRaises(pipeline.CapExceededError):
            pipeline.build_translation_plan(
                source_video_id="vid-over-cost",
                source_video_url="https://example.com/a.mp4",
                languages=["ja", "en", "es", "fr"],
                duration_seconds=100,
                max_duration_cap_seconds=120,
                max_cost_cap_usd=1.0,
            )

    def test_ssrf_and_url_sanitization(self) -> None:
        with self.assertRaises(pipeline.SecurityValidationError):
            pipeline.build_translation_plan(
                source_video_id="vid-http",
                source_video_url="http://example.com/video.mp4",
                languages=["ja"],
                duration_seconds=10,
            )

        with self.assertRaises(pipeline.SecurityValidationError):
            pipeline.build_translation_plan(
                source_video_id="vid-ip",
                source_video_url="https://127.0.0.1/video.mp4",
                languages=["ja"],
                duration_seconds=10,
            )

        for blocked_ip in ("169.254.169.254", "100.64.0.1", "::ffff:127.0.0.1"):
            family = socket.AF_INET6 if ":" in blocked_ip else socket.AF_INET
            with mock.patch(
                "did_video_translate_pipeline.socket.getaddrinfo",
                return_value=[(family, socket.SOCK_STREAM, 6, "", (blocked_ip, 443))],
            ):
                with self.assertRaises(pipeline.SecurityValidationError):
                    pipeline.resolve_and_validate_https_url("https://metadata.internal/latest")

        sanitized = pipeline.sanitize_url_for_log("https://cdn.example.com/v1/vid.mp4?sig=abc#frag")
        self.assertEqual(sanitized, "https://cdn.example.com/v1/vid.mp4")

    def test_live_create_and_poll_contracts_with_mock_transport(self) -> None:
        plan = pipeline.build_translation_plan(
            source_video_id="intro_01",
            source_video_url="https://cdn.example.com/intro.mp4",
            languages=["ja", "es"],
            source_language="English",
            duration_seconds=30.0,
            max_duration_cap_seconds=120,
            max_cost_cap_usd=5.0,
            webhook_url="https://hooks.example.com/did-callback",
        )
        captured: list[tuple[str, str, dict[str, str], dict[str, object] | None]] = []

        def fake_request(method, url, *, headers, body=None, timeout=20):  # noqa: ANN001
            captured.append((method, url, headers, body))
            if method == "POST":
                return {
                    "translations": [
                        {"id": "trs_ja_1", "status": "validating", "group_id": "grp_1"},
                        {"id": "trs_es_1", "status": "validating", "group_id": "grp_1"},
                    ]
                }
            return {
                "id": "trs_ja_1",
                "status": "done",
                "result_url": "https://results.example.com/ja.mp4",
                "subtitles_url": "https://results.example.com/ja.vtt",
                "thumbnail_url": "https://results.example.com/ja.jpg",
                "group_id": "grp_1",
            }

        with mock.patch(
            "did_video_translate_pipeline.socket.getaddrinfo",
            return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
        ):
            created = pipeline.create_translations_live(
                plan,
                auth_credential="probe-did-val",
                request_fn=fake_request,
            )
            polled = pipeline.poll_translation_status_live(
                "trs_ja_1",
                auth_credential="probe-did-val",
                request_fn=fake_request,
            )

        self.assertEqual(len(created["translations"]), 2)
        self.assertEqual(captured[0][0], "POST")
        self.assertEqual(captured[0][1], "https://api.d-id.com/translations")
        self.assertEqual(captured[0][2]["Authorization"], "Basic probe-did-val")
        self.assertEqual(
            captured[0][3],
            {
                "source_url": "https://cdn.example.com/intro.mp4",
                "languages": ["Japanese", "Spanish"],
                "source_language": "English",
                "webhook": "https://hooks.example.com/did-callback",
            },
        )
        self.assertEqual(polled["status"], "done")
        self.assertEqual(polled["result_url"], "https://results.example.com/ja.mp4")

    def test_cli_self_test_and_dry_run_outputs(self) -> None:
        self_test_proc = subprocess.run(
            [sys.executable, str(REPO_ROOT / "scripts/did_video_translate_pipeline.py"), "--self-test"],
            capture_output=True,
            text=True,
            check=True,
        )
        parsed = json.loads(self_test_proc.stdout)
        self.assertEqual(parsed["self_test"], "passed")
        self.assertTrue(parsed["duration_cap_rejected"])
        self.assertTrue(parsed["cost_cap_rejected"])

        dry_proc = subprocess.run(
            [sys.executable, str(REPO_ROOT / "scripts/did_video_translate_pipeline.py"), "--dry-run"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("D-ID Video Translate Multilingual Lip-Sync (#2660)", dry_proc.stdout)
        self.assertIn("dry-run", dry_proc.stdout)


if __name__ == "__main__":
    unittest.main()
