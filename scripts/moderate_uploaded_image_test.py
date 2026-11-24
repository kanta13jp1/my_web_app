#!/usr/bin/env python3
"""Offline unit tests for scripts/moderate_uploaded_image.py (#2644)."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from pathlib import Path
import socket
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import moderate_uploaded_image as mui


class _FakeHttpResponse:
    def __init__(self, status: int, body: bytes) -> None:
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body


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
        with mock.patch("moderate_uploaded_image._PinnedHTTPSConnection") as mocked_conn:
            with self.assertRaises(PermissionError):
                mui.moderate_uploaded_image(
                    storage_bucket="user-uploads",
                    storage_path="nature_mountain.jpg",
                    external_transfer_consented=False,
                    use_external_vision=True,
                )
            mocked_conn.assert_not_called()

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

    def test_pinned_https_connection_pins_resolved_ip_and_sets_sni_host(self) -> None:
        endpoint = "https://vision.example.com/v1/classify"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        captured: dict[str, object] = {}

        fake_raw_sock = mock.MagicMock()
        fake_tls_sock = mock.MagicMock()
        fake_ctx = mock.MagicMock()
        fake_ctx.wrap_socket.return_value = fake_tls_sock

        def fake_create_conn(address: tuple[str, int], timeout: float, source_addr: object) -> object:
            captured["connect_address"] = address
            return fake_raw_sock

        def fake_request(self_conn: mui._PinnedHTTPSConnection, method: str, target: str, body: bytes | None = None, headers: dict[str, str] | None = None) -> None:
            captured["method"] = method
            captured["target"] = target
            captured["headers"] = dict(headers or {})
            self_conn.connect()

        def fake_getresponse(self_conn: mui._PinnedHTTPSConnection) -> _FakeHttpResponse:
            return _FakeHttpResponse(
                200,
                json.dumps({"tags": ["Food", "Lunch"], "safety_score": 0.94}).encode("utf-8"),
            )

        env_var = "VISION_" + "API_KEY"
        with mock.patch.dict(os.environ, {env_var: "stub", "VISION_API_ENDPOINT": endpoint}):
            with mock.patch("moderate_uploaded_image.socket.getaddrinfo", return_value=fake_addrinfo):
                with mock.patch("moderate_uploaded_image.socket.create_connection", side_effect=fake_create_conn):
                    with mock.patch("moderate_uploaded_image.ssl.create_default_context", return_value=fake_ctx):
                        with mock.patch.object(mui._PinnedHTTPSConnection, "request", fake_request):
                            with mock.patch.object(mui._PinnedHTTPSConnection, "getresponse", fake_getresponse):
                                with mock.patch.object(mui._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                    res = mui.moderate_uploaded_image(
                                        storage_bucket="user-uploads",
                                        storage_path="food_lunch.png",
                                        external_transfer_consented=True,
                                        use_external_vision=True,
                                    )

        self.assertEqual(captured["connect_address"], ("93.184.216.34", 443))
        fake_ctx.wrap_socket.assert_called_once_with(fake_raw_sock, server_hostname="vision.example.com")
        self.assertEqual(captured["headers"]["Host"], "vision.example.com")  # type: ignore[index]
        self.assertEqual(res.tags, ["food", "lunch"])
        self.assertEqual(res.moderation_status, "approved")

    def test_external_vision_http_error_and_redirect_sanitize_url_and_block_ssrf(self) -> None:
        endpoint = "https://vision.example.com/v1/classify?key=query_param_should_strip"
        fake_addrinfo = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]

        env_var = "VISION_" + "API_KEY"
        with mock.patch.dict(os.environ, {env_var: "stub", "VISION_API_ENDPOINT": endpoint}):
            with mock.patch("moderate_uploaded_image.socket.getaddrinfo", return_value=fake_addrinfo):
                for status_code in (302, 503):
                    with mock.patch.object(mui._PinnedHTTPSConnection, "request", lambda *args, **kwargs: None):
                        with mock.patch.object(
                            mui._PinnedHTTPSConnection,
                            "getresponse",
                            lambda *args, code=status_code: _FakeHttpResponse(code, b"{}"),
                        ):
                            with mock.patch.object(mui._PinnedHTTPSConnection, "close", lambda self_conn: None):
                                with self.assertRaises(RuntimeError) as ctx:
                                    mui.moderate_uploaded_image(
                                        storage_bucket="user-uploads",
                                        storage_path="food_lunch.png",
                                        external_transfer_consented=True,
                                        use_external_vision=True,
                                    )
                    self.assertIn(str(status_code), str(ctx.exception))
                    self.assertNotIn("query_param_should_strip", str(ctx.exception))
                    self.assertNotIn("?", str(ctx.exception))

        # Private/link-local DNS resolution must be rejected before connecting.
        private_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("169.254.169.254", 443))]
        with mock.patch("moderate_uploaded_image.socket.getaddrinfo", return_value=private_dns):
            with self.assertRaises(ValueError):
                mui.resolve_and_validate_external_vision_url("https://rebind.example.com/v1/classify")


if __name__ == "__main__":
    unittest.main()
