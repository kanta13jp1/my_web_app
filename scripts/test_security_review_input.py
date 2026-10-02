import unittest
from pathlib import Path

from scripts.security_review_input import (
    redact_secrets,
    redact_secrets_with_count,
    risk_reasons,
)


class SecurityReviewInputTest(unittest.TestCase):
    def test_redacts_common_credentials(self) -> None:
        value = "OPENAI_API_KEY=redact-this-test-value\nAuthorization: Bearer abcdefghijklmnop\n"
        redacted = redact_secrets(value)
        self.assertNotIn("redact-this", redacted)
        self.assertNotIn("abcdefghijklmnop", redacted)
        self.assertEqual(redacted.count("[REDACTED]"), 2)

    def test_redacts_supabase_and_provider_credential_shapes(self) -> None:
        jwt = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature123456"
        value = "\n".join(
            (
                f"SUPABASE_SERVICE_ROLE_KEY={jwt}",
                "token=sb_secret_abcdefghijklmnopqrstuvwxyz",
                "github_pat_abcdefghijklmnopqrstuvwxyz",
                "sk-proj-abcdefghijklmnopqrstuvwxyz",
            )
        )
        redacted, count = redact_secrets_with_count(value)
        self.assertNotIn(jwt, redacted)
        self.assertNotIn("sb_secret_", redacted)
        self.assertNotIn("github_pat_", redacted)
        self.assertNotIn("sk-proj-", redacted)
        self.assertEqual(count, 4)

    def test_context_exclusion_baseline_is_present(self) -> None:
        root = Path(__file__).resolve().parents[1]
        rules = {
            line.strip()
            for line in (root / ".aiexclude").read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertTrue(
            {
                "**/.env",
                "**/.env.*",
                "**/.mcp.json",
                "**/*.pem",
                "**/*serviceAccountKey*.json",
                "supabase/.temp/",
            }.issubset(rules)
        )

    def test_ai_review_redacts_before_provider_consumes_diff(self) -> None:
        root = Path(__file__).resolve().parents[1]
        workflow = (root / ".github/workflows/claude-agent-review.yml").read_text(
            encoding="utf-8"
        )
        self.assertLess(
            workflow.index("--redact-only"),
            workflow.index("DIFF=$(head -c 10000 pr_diff.txt)"),
        )
        self.assertNotIn("head -n 400 > pr_diff.txt", workflow)

    def test_top_level_pull_request_shape_preserves_text_risk(self) -> None:
        event = {"title": "Change authentication token flow", "body": "normal", "labels": []}
        reasons = risk_reasons(event, ["README.md"])
        self.assertIn("Title/body contains high-risk keywords.", reasons)


if __name__ == "__main__":
    unittest.main()
