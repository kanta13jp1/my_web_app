import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ai_output_copyright_safety_check import (
    SourceReference,
    validate_ai_output,
)


class AiOutputCopyrightSafetyCheckTest(unittest.TestCase):
    def test_clean_output_passes(self) -> None:
        result = validate_ai_output(
            "Net worth improved compared with last month.",
            [SourceReference("src-1", "Savings balance increased steadily.")],
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.blocked_categories, [])
        self.assertEqual(result.quote_violations, [])
        self.assertIsNone(result.issue_alert_payload)

    def test_long_verbatim_quote_fails_and_builds_dry_run_alert(self) -> None:
        quote = (
            "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda "
            "mu nu xi omicron pi rho"
        )
        result = validate_ai_output(
            f"Quoted: {quote}",
            [SourceReference("src-long", quote)],
        )
        self.assertFalse(result.allowed)
        self.assertEqual(len(result.quote_violations), 1)
        self.assertEqual(result.quote_violations[0].word_count, 17)
        self.assertIsNotNone(result.issue_alert_payload)
        assert result.issue_alert_payload is not None
        self.assertTrue(result.issue_alert_payload.dry_run)
        self.assertIn("src-long", result.issue_alert_payload.body)

    def test_multiple_quotes_from_same_source_fail(self) -> None:
        src = (
            "first six word matching phrase here "
            "middle filler words "
            "second six word matching phrase here"
        )
        out = (
            "A: first six word matching phrase here. "
            "B: second six word matching phrase here."
        )
        result = validate_ai_output(out, [SourceReference("src-multi", src)])
        self.assertFalse(result.allowed)
        self.assertEqual(result.quote_violations[0].quote_count, 2)

    def test_safety_categories_are_blocked(self) -> None:
        result = validate_ai_output(
            "Do not ask for how to commit suicide or synthesize methamphetamine."
        )
        self.assertFalse(result.allowed)
        self.assertEqual(
            result.blocked_categories,
            ["self_harm", "illicit_drugs"],
        )

    def test_sample_dry_run_cli(self) -> None:
        script = (
            Path(__file__).resolve().parent
            / "ai_output_copyright_safety_check.py"
        )
        proc = subprocess.run(
            [sys.executable, str(script), "--sample-dry-run", "--json"],
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(proc.stdout)
        self.assertTrue(payload["ok"])


if __name__ == "__main__":
    unittest.main()
