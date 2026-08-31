from __future__ import annotations

import unittest
from urllib.request import Request

from scripts.validate_shared_secret_environment import validate_environment


class _Response:
    def __init__(self, status: int) -> None:
        self.status = status

    def __enter__(self) -> "_Response":
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def read(self, _size: int) -> bytes:
        return b"{"


class ValidateSharedSecretEnvironmentTest(unittest.TestCase):
    def test_validates_presence_and_read_only_supabase_auth(self) -> None:
        captured: list[Request] = []

        def opener(request: Request, *, timeout: int) -> _Response:
            self.assertEqual(timeout, 20)
            captured.append(request)
            return _Response(200)

        result = validate_environment(
            environment="content-automation-production",
            expect_anthropic=True,
            expect_supabase=True,
            environ={
                "ANTHROPIC_API_KEY": "anthropic-fixture",
                "SUPABASE_SERVICE_ROLE_KEY": "supabase-fixture",
                "SUPABASE_URL": "https://example.supabase.co",
            },
            opener=opener,
        )

        self.assertTrue(result.anthropic_present)
        self.assertEqual(result.supabase_status, 200)
        self.assertEqual(captured[0].full_url, "https://example.supabase.co/rest/v1/")
        self.assertEqual(captured[0].get_header("Apikey"), "supabase-fixture")

    def test_validates_anon_reads_for_rls_approved_tables(self) -> None:
        captured: list[Request] = []

        def opener(request: Request, *, timeout: int) -> _Response:
            self.assertEqual(timeout, 20)
            captured.append(request)
            return _Response(200)

        result = validate_environment(
            environment="content-automation-production",
            expect_anthropic=False,
            expect_supabase=False,
            expect_public_reads=True,
            environ={
                "SUPABASE_ANON_KEY": "anon-fixture",
                "SUPABASE_URL": "https://example.supabase.co",
            },
            opener=opener,
        )

        self.assertEqual(result.public_read_statuses, (200, 200))
        self.assertEqual(
            [request.full_url for request in captured],
            [
                "https://example.supabase.co/rest/v1/competitors?select=id,display_name&is_active=eq.true&limit=1",
                "https://example.supabase.co/rest/v1/ai_circuit_breaker?provider=eq.anthropic&select=state,expires_at",
            ],
        )
        self.assertTrue(
            all(request.get_header("Apikey") == "anon-fixture" for request in captured)
        )

    def test_rejects_missing_required_secret_without_network(self) -> None:
        with self.assertRaisesRegex(ValueError, "ANTHROPIC_API_KEY did not resolve"):
            validate_environment(
                environment="ai-review-production",
                expect_anthropic=True,
                expect_supabase=False,
                environ={},
                opener=lambda *_args, **_kwargs: self.fail("network must not run"),
            )

    def test_rejects_non_https_supabase_url(self) -> None:
        with self.assertRaisesRegex(ValueError, "SUPABASE_URL must be an https URL"):
            validate_environment(
                environment="analytics-production",
                expect_anthropic=False,
                expect_supabase=True,
                environ={
                    "SUPABASE_SERVICE_ROLE_KEY": "supabase-fixture",
                    "SUPABASE_URL": "http://example.invalid",
                },
            )

    def test_rejects_non_200_canary(self) -> None:
        with self.assertRaisesRegex(ValueError, "returned HTTP 401"):
            validate_environment(
                environment="analytics-production",
                expect_anthropic=False,
                expect_supabase=True,
                environ={
                    "SUPABASE_SERVICE_ROLE_KEY": "supabase-fixture",
                    "SUPABASE_URL": "https://example.supabase.co",
                },
                opener=lambda *_args, **_kwargs: _Response(401),
            )


if __name__ == "__main__":
    unittest.main()
