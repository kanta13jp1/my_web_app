import io
import json
import sys
import unittest
import urllib.error
from email.message import Message
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / ".github" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import competitor_stage as cs  # noqa: E402
import competitor_url_verifier as cuv  # noqa: E402


class _FakeResp:
    def __init__(self, status: int) -> None:
        self.status = status

    def __enter__(self) -> "_FakeResp":
        return self

    def __exit__(self, *args: object) -> None:
        return None


class CompetitorUrlVerificationTest(unittest.TestCase):
    def test_verify_source_url_200_clears_manual_review(self) -> None:
        methods: list[str] = []

        def fake_opener(req, timeout=5.0):
            methods.append(req.get_method())
            return _FakeResp(200)

        res = cuv.verify_source_url(
            "https://example.com/pricing",
            opener=fake_opener,
            checked_at="2026-11-24T00:00:00Z",
        )
        self.assertEqual(methods, ["HEAD"])
        self.assertEqual(res["source_url_status_code"], 200)
        self.assertFalse(res["needs_manual_review"])
        self.assertIsNone(res["source_url_error"])

    def test_verify_source_url_404_flags_manual_review(self) -> None:
        def fake_opener(req, timeout=5.0):
            raise urllib.error.HTTPError(
                req.full_url, 404, "Not Found", Message(), io.BytesIO(b"")
            )

        res = cuv.verify_source_url(
            "https://example.com/missing-hallucinated-page",
            opener=fake_opener,
            checked_at="2026-11-24T00:00:00Z",
        )
        self.assertEqual(res["source_url_status_code"], 404)
        self.assertTrue(res["needs_manual_review"])
        self.assertIn("404", str(res["source_url_error"]))

    def test_verify_source_url_405_falls_back_to_get(self) -> None:
        methods: list[str] = []

        def fake_opener(req, timeout=5.0):
            m = req.get_method()
            methods.append(m)
            if m == "HEAD":
                raise urllib.error.HTTPError(
                    req.full_url, 405, "Method Not Allowed", Message(), io.BytesIO(b"")
                )
            return _FakeResp(200)

        res = cuv.verify_source_url("https://example.com/docs", opener=fake_opener)
        self.assertEqual(methods, ["HEAD", "GET"])
        self.assertEqual(res["source_url_status_code"], 200)
        self.assertFalse(res["needs_manual_review"])

    def test_verify_source_url_blocks_private_and_non_http_urls(self) -> None:
        for bad_url in (
            "",
            "ftp://example.com/file",
            "http://localhost:8080/admin",
            "http://127.0.0.1/internal",
            "http://169.254.169.254/latest/meta-data",
        ):
            res = cuv.verify_source_url(bad_url)
            self.assertTrue(res["needs_manual_review"], msg=bad_url)
            self.assertIsNone(res["source_url_status_code"], msg=bad_url)

    def test_stage_candidates_attaches_url_verification_payload(self) -> None:
        captured: list[dict[str, object]] = []

        def fake_opener(req, timeout=20):
            if "/competitor_candidates" in req.full_url:
                captured.append(json.loads(req.data.decode("utf-8")))
            return _FakeResp(201)

        def fake_verifier(url):
            if url and "404" in url:
                return {
                    "source_url_status_code": 404,
                    "source_url_checked_at": "2026-11-24T00:00:00Z",
                    "source_url_error": "HTTP 404: Not Found",
                    "needs_manual_review": True,
                }
            return {
                "source_url_status_code": 200,
                "source_url_checked_at": "2026-11-24T00:00:00Z",
                "source_url_error": None,
                "needs_manual_review": False,
            }

        new_cnt, skip_cnt, err_cnt, _ = cs.stage_candidates(
            supabase_url="https://example.supabase.co",
            service_key="test-key",
            candidates=[
                {
                    "id": "valid-app",
                    "display_name": "Valid App",
                    "website": "https://valid.example.com",
                },
                {
                    "id": "hallucinated-app",
                    "display_name": "Hallucinated App",
                    "website": "https://bad.example.com/404",
                },
            ],
            existing=[],
            week_str="2026-48",
            opener=fake_opener,
            verify_urls=True,
            url_verifier=fake_verifier,
        )
        self.assertEqual((new_cnt, skip_cnt, err_cnt), (2, 0, 0))
        self.assertEqual(len(captured), 2)
        self.assertFalse(captured[0]["needs_manual_review"])
        self.assertEqual(captured[0]["source_url_status_code"], 200)
        self.assertTrue(captured[1]["needs_manual_review"])
        self.assertEqual(captured[1]["source_url_status_code"], 404)
        self.assertEqual(captured[1]["review_decision"], "pending")


if __name__ == "__main__":
    unittest.main()
