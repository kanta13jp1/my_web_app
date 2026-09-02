import unittest

from scripts.security_review_input import redact_secrets, risk_reasons


class SecurityReviewInputTest(unittest.TestCase):
    def test_redacts_common_credentials(self) -> None:
        value = "OPENAI_API_KEY=redact-this-test-value\nAuthorization: Bearer abcdefghijklmnop\n"
        redacted = redact_secrets(value)
        self.assertNotIn("redact-this", redacted)
        self.assertNotIn("abcdefghijklmnop", redacted)
        self.assertEqual(redacted.count("[REDACTED]"), 2)

    def test_top_level_pull_request_shape_preserves_text_risk(self) -> None:
        event = {"title": "Change authentication token flow", "body": "normal", "labels": []}
        reasons = risk_reasons(event, ["README.md"])
        self.assertIn("Title/body contains high-risk keywords.", reasons)


if __name__ == "__main__":
    unittest.main()
