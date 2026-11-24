#!/usr/bin/env python3
"""Offline unit tests for scripts/moderate_uploaded_image.py (#2644)."""

from __future__ import annotations

import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock
from urllib import error as urllib_error

sys.path.insert(0, str(Path(__file__).resolve().parent))
import moderate_uploaded_image as mui


class ModerateUploadedImageTests(unittest.TestCase):
    def test_hmac_verification_fails_closed_on_missing_or_tampered_signature(self) -> None:
        key_mat = "wh_hmac_validation_material"
        body = json.dumps({"bucket_id": "uploads", "name": "receipt_sample.png"}).encode("utf-8")
        digest = hmac.new(key_mat.encode("utf-8"), body, hashlib.sha256).hexdigest()

        self.assertTrue(mui.verify_webhook_signature(body, f"sha256={digest}", key_mat))
        self.assertFalse(mui.verify_webhook_signature(body, "", key_mat))
        self.assertFalse(mui.verify_webhook_signature(body, f"sha256={'0' * 64}", key_mat))
        self.assertFalse(mui.verify_webhook_signature(body, digest, ""))

        with self.assertRaises(PermissionError):
            mui.process_storage_webhook(
                payload_bytes=body,
                signature_header="sha256=" + ("a" * 64),
                hmac_key_material=key_mat,
            )

    def test_rejects_path_traversal_and_invalid_extensions(self) -> None:
        for bad_path in ("../etc/passwd.png", "/abs/path.png", "folder\\win.jpg", "payload.exe", "nested/../x.webp"):
            with self.assertRaises(ValueError):
                mui.validate_storage_path("user-uploads", bad_path)

    def test_external_transfer_blocked_without_explicit_consent(self) -> None:
        with mock.patch("moderate_uploaded_image.urllib_request.urlopen") as mocked_open:
            with self.assertRaises(PermissionError):
                mui.moderate_uploaded_image(
                    storage_bucket="user-uploads",
                    storage_path="nature_mountain.jpg",
                    external_transfer_consented=False,
                    use_external_vision=True,
                )
            mocked_open.assert_not_called()

    def test_low_safety_score_forces_hidden_and_normalizes_tags(self) -> None:
        unsafe = mui.moderate_uploaded_image(
            storage_bucket="user-uploads",
            storage_path="flagged_nsfw_sample.png",
            hint_tags=["Receipt", "receipt", "Document_Scan", "a", "Safe Tag!"],
        )
        self.assertLess(unsafe.safety_score, 0.50)
        self.assertEqual(unsafe.moderation_status, "hidden")
        self.assertTrue(unsafe.is_hidden)
        self.assertIn("receipt", unsafe.tags)
        self.assertIn("document_scan", unsafe.tags)
        self.assertEqual(unsafe.tags.count("receipt"), 1)

        mid = mui.evaluate_moderation_decision(0.62)
        self.assertEqual(mid, ("flagged", False))
        ok = mui.evaluate_moderation_decision(0.92)
        self.assertEqual(ok, ("approved", False))

    def test_external_vision_http_error_sanitizes_url_and_raises_runtime_error(self) -> None:
        endpoint = "https://vision.example.com/v1/classify?key=query_param_should_strip"
        http_err = urllib_error.HTTPError(
            url=endpoint,
            code=503,
            msg="Service Unavailable",
            hdrs=None,  # type: ignore[arg-type]
            fp=io.BytesIO(b"{}"),
        )
        env_var = "VISION_" + "API_KEY"
        with mock.patch.dict(os.environ, {env_var: "stub", "VISION_API_ENDPOINT": endpoint}):
            with mock.patch("moderate_uploaded_image.validate_external_vision_url", return_value=endpoint):
                with mock.patch("moderate_uploaded_image.urllib_request.urlopen", side_effect=http_err):
                    with self.assertRaises(RuntimeError) as ctx:
                        mui.moderate_uploaded_image(
                            storage_bucket="user-uploads",
                            storage_path="food_lunch.png",
                            external_transfer_consented=True,
                            use_external_vision=True,
                        )
        self.assertIn("503", str(ctx.exception))
        self.assertNotIn("query_param_should_strip", str(ctx.exception))
        self.assertNotIn("?", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
