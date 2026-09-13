import os
import re
import sys
import tempfile
import types
import unittest
import urllib.error
import urllib.parse
from pathlib import Path
from unittest.mock import patch

from scripts.run_dual_security_review import (
    codex_review,
    create_openai_client,
    github_actions_oidc_token_provider,
    is_pass_verdict,
    main,
    request_json,
    sanitize_output,
)


class FakeHTTPResponse:
    def __init__(self, payload: bytes) -> None:
        self.payload = payload

    def __enter__(self) -> "FakeHTTPResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def read(self) -> bytes:
        return self.payload


class DualSecurityReviewTest(unittest.TestCase):
    def test_sanitizes_known_and_structured_secrets_from_model_output(self) -> None:
        known = "known-secret-value"
        value = f"echo {known}\nOPENAI_API_KEY=redact-this-model-value\n"
        sanitized = sanitize_output(value, [known])
        self.assertNotIn(known, sanitized)
        self.assertNotIn("redact-this-model", sanitized)
        self.assertEqual(sanitized.count("[REDACTED]"), 2)

    def test_requires_an_exact_pass_verdict_line(self) -> None:
        self.assertTrue(is_pass_verdict("VERDICT: PASS\nNo findings."))
        self.assertFalse(is_pass_verdict("VERDICT: PASS WITH CAVEATS\nReview me."))
        self.assertFalse(is_pass_verdict("prefix VERDICT: PASS\nNo findings."))

    def test_github_oidc_provider_requests_the_exact_encoded_audience(self) -> None:
        environment = {
            "ACTIONS_ID_TOKEN_REQUEST_URL": "https://example.invalid/oidc?api-version=1",
            "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "github-request-token",
        }
        with patch.dict(os.environ, environment, clear=False), patch(
            "scripts.run_dual_security_review.urllib.request.urlopen",
            return_value=FakeHTTPResponse(b'{"value":"short-lived-oidc-token"}'),
        ) as urlopen:
            provider = github_actions_oidc_token_provider(
                "https://api.openai.com/v1"
            )
            self.assertEqual(provider["get_token"](), "short-lived-oidc-token")

        request = urlopen.call_args.args[0]
        query = urllib.parse.parse_qs(urllib.parse.urlparse(request.full_url).query)
        self.assertEqual(query["audience"], ["https://api.openai.com/v1"])
        self.assertEqual(
            request.get_header("Authorization"), "bearer github-request-token"
        )

    def test_codex_review_uses_responses_api_without_persistent_storage(self) -> None:
        captured: dict[str, object] = {}

        class FakeResponses:
            def create(self, **kwargs: object) -> object:
                captured.update(kwargs)
                return type("Response", (), {"output_text": "VERDICT: PASS\nOK"})()

        fake_client = type("Client", (), {"responses": FakeResponses()})()
        with patch(
            "scripts.run_dual_security_review.create_openai_client",
            return_value=fake_client,
        ):
            result = codex_review("bounded diff", "gpt-5.3-codex")

        self.assertEqual(result, "VERDICT: PASS\nOK")
        self.assertEqual(captured["model"], "gpt-5.3-codex")
        self.assertFalse(captured["store"])
        self.assertEqual(captured["max_output_tokens"], 2500)

    def test_openai_client_wires_only_workload_identity_configuration(self) -> None:
        captured: dict[str, object] = {}
        fake_openai = types.ModuleType("openai")

        class FakeOpenAI:
            def __init__(self, **kwargs: object) -> None:
                captured.update(kwargs)

        fake_openai.OpenAI = FakeOpenAI  # type: ignore[attr-defined]
        environment = {
            "OPENAI_WIF_AUDIENCE": "https://api.openai.com/v1",
            "OPENAI_IDENTITY_PROVIDER_ID": "provider-id",
            "OPENAI_SERVICE_ACCOUNT_ID": "service-account-id",
            "ACTIONS_ID_TOKEN_REQUEST_URL": "https://example.invalid/oidc",
            "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "github-request-token",
        }
        with patch.dict(os.environ, environment, clear=False), patch.dict(
            sys.modules, {"openai": fake_openai}
        ):
            create_openai_client()

        workload_identity = captured["workload_identity"]
        self.assertIsInstance(workload_identity, dict)
        self.assertEqual(workload_identity["identity_provider_id"], "provider-id")
        self.assertEqual(workload_identity["service_account_id"], "service-account-id")
        self.assertEqual(workload_identity["provider"]["token_type"], "jwt")
        self.assertNotIn("api_key", captured)

    def test_http_error_reports_status_without_body_or_url(self) -> None:
        error = urllib.error.HTTPError(
            "https://example.invalid/private?token=secret",
            401,
            "Unauthorized secret body",
            None,
            None,
        )
        with patch(
            "scripts.run_dual_security_review.urllib.request.urlopen",
            side_effect=error,
        ), self.assertRaisesRegex(RuntimeError, r"^HTTPError_401$"):
            request_json("https://example.invalid", {}, {"safe": True})

    def test_missing_credentials_fail_closed_with_separate_evidence_ids(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            review_input = root / "input.txt"
            report = root / "report.md"
            review_input.write_text("bounded test diff", encoding="utf-8")
            arguments = [
                "run_dual_security_review.py",
                "--input",
                str(review_input),
                "--report",
                str(report),
                "--repo",
                "kanta13jp1/my_web_app",
                "--pr-number",
                "1352",
                "--run-id",
                "missing-credential-test",
            ]
            environment = {
                "ANTHROPIC_API_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "DECISION_EVENTS_URL": "",
                "OPENAI_WIF_AUDIENCE": "",
                "OPENAI_IDENTITY_PROVIDER_ID": "",
                "OPENAI_SERVICE_ACCOUNT_ID": "",
                "ACTIONS_ID_TOKEN_REQUEST_URL": "",
                "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "",
            }
            with patch.object(sys, "argv", arguments), patch.dict(
                os.environ,
                environment,
                clear=False,
            ):
                self.assertEqual(main(), 1)

            output = report.read_text(encoding="utf-8")
            self.assertIn("github-run-missing-credential-test-claude", output)
            self.assertIn("github-run-missing-credential-test-codex", output)
            self.assertEqual(output.count("UNAVAILABLE — not counted as a review."), 2)
            self.assertIn("This check fails closed.", output)
            self.assertIn("required WIF configuration is unavailable", output)

    def test_workflow_confines_credentials_to_trusted_main_execution(self) -> None:
        root = Path(__file__).resolve().parents[1]
        workflow = (
            root / ".github/workflows/high-risk-dual-security-review.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("id-token: write", workflow)
        self.assertIn("branches: [main]", workflow)
        self.assertNotIn("branches: [main, staging, develop]", workflow)
        self.assertIn("name: high-risk-security-review", workflow)
        self.assertIn("deployment: false", workflow)
        self.assertIn("ref: ${{ github.sha }}", workflow)
        self.assertIn('[ "$GITHUB_REF" != "refs/heads/main" ]', workflow)
        self.assertIn('[ "$base_ref" != "main" ]', workflow)
        self.assertIn(
            'git show "$trusted:scripts/run_dual_security_review.py"', workflow
        )
        self.assertNotIn(
            'git show "$base:scripts/run_dual_security_review.py"', workflow
        )
        self.assertIn("OWNER|MEMBER|COLLABORATOR", workflow)
        self.assertIn('EVENT_NAME" = "workflow_dispatch', workflow)
        self.assertIn("python-version: '3.12'", workflow)
        self.assertIn("--only-binary=:all: --require-hashes", workflow)
        self.assertIn("requirements-high-risk-security-review.txt", workflow)
        self.assertIn("vars.OPENAI_WIF_AUDIENCE", workflow)
        self.assertIn("vars.OPENAI_IDENTITY_PROVIDER_ID", workflow)
        self.assertIn("vars.OPENAI_SERVICE_ACCOUNT_ID", workflow)
        self.assertNotIn("secrets.OPENAI_API_KEY", workflow)
        self.assertNotIn("pip install openai==", workflow)

    def test_security_review_dependency_lock_is_complete_and_hashed(self) -> None:
        root = Path(__file__).resolve().parents[1]
        lock = (
            root / "scripts/requirements-high-risk-security-review.txt"
        ).read_text(encoding="utf-8")
        requirements = re.findall(
            r"(?m)^([a-z0-9-]+)==([^\s\\]+)",
            lock,
        )
        names = [name for name, _ in requirements]
        self.assertEqual(len(requirements), 14)
        self.assertEqual(len(names), len(set(names)))
        versions = [(name, version) for name, version in requirements]
        self.assertIn(("openai", "3.6.0"), versions)
        self.assertNotRegex(
            lock,
            r"(?:>=|<=|~=|!=|(?<![=])>(?!=)|(?<![=])<(?!=))",
        )
        hashes = re.findall(
            r"\s+--hash=sha256:([0-9a-f]{64})",
            lock,
        )
        self.assertGreaterEqual(len(hashes), 14)


if __name__ == "__main__":
    unittest.main()
