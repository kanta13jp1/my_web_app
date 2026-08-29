import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.run_dual_security_review import is_pass_verdict, main, sanitize_output


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
                "OPENAI_API_KEY": "",
                "ANTHROPIC_API_KEY": "",
                "SUPABASE_SERVICE_ROLE_KEY": "",
                "DECISION_EVENTS_URL": "",
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


if __name__ == "__main__":
    unittest.main()
