import unittest
import tempfile
import os
from unittest.mock import patch
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
        self.assertLess(workflow.index("ai_review_gate.py prepare"), workflow.index("ai_review_gate.py review"))
        self.assertIn("ref: ${{ github.sha }}", workflow)
        from scripts import ai_review_gate as gate
        secret = "redact-this-test-value"
        pr = {"state": "open", "draft": False, "head": {"sha": "a"*40},
              "base": {"ref": "main", "sha": "b"*40}}
        def git(*args):
            if args[:2] == ("rev-parse", "HEAD"): return ("c"*40).encode()
            if args[0] == "rev-parse": return ("a"*40).encode()
            if args[0] == "fetch": return b""
            if "--name-only" in args: return b"example.py\0"
            return ("diff --git a/example.py b/example.py\n+API_KEY="+secret).encode()
        env = {"PR_NUMBER": "1", "GITHUB_REPOSITORY": "owner/repo", "GITHUB_SHA": "c"*40,
               "GITHUB_RUN_ID": "1", "GITHUB_RUN_ATTEMPT": "1", "GITHUB_EVENT_NAME": "workflow_dispatch"}
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, env), patch.object(gate, "git", side_effect=git), patch.object(gate, "github", side_effect=[pr, {"id": 1}]):
            directory = Path(temp)
            gate.prepare(directory)
            sanitized = (directory/"input.txt").read_text(encoding="utf-8")
            self.assertNotIn(secret, sanitized)
            self.assertIn("[REDACTED]", sanitized)
            self.assertFalse((directory/"review.diff").exists())

    def test_top_level_pull_request_shape_preserves_text_risk(self) -> None:
        event = {"title": "Change authentication token flow", "body": "normal", "labels": []}
        reasons = risk_reasons(event, ["README.md"])
        self.assertIn("Title/body contains high-risk keywords.", reasons)


if __name__ == "__main__":
    unittest.main()

