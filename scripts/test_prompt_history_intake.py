import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from prompt_history_intake import (
    build_investigation_issue_payload,
    diff_prompt_snapshots,
    normalize_prompt_snapshot,
)


class PromptHistoryIntakeTest(unittest.TestCase):
    def test_normalization_is_deterministic_and_marks_unverified(self) -> None:
        snap_a = normalize_prompt_snapshot(
            {
                "provider": " Anthropic ",
                "model_name": "claude-sonnet",
                "version_tag": "v1",
                "captured_at_iso": "2026-11-01T00:00:00Z",
                "sections": {"b": "two\r\n", "a": " one "},
            }
        )
        snap_b = normalize_prompt_snapshot(
            {
                "provider": "anthropic",
                "model_name": "claude-sonnet",
                "version_tag": "v1",
                "captured_at_iso": "2026-11-01T00:00:00+00:00",
                "sections": {"a": "one", "b": "two"},
            }
        )
        self.assertEqual(snap_a.content_digest, snap_b.content_digest)
        self.assertEqual(snap_a.verification_status, "未確認")

    def test_breaking_diff_and_dry_run_issue_payload(self) -> None:
        prev = normalize_prompt_snapshot(
            {
                "provider": "anthropic",
                "model_name": "claude-sonnet",
                "version_tag": "v1",
                "captured_at_iso": "2026-11-01T00:00:00Z",
                "sections": {"identity": "A", "safety": "B"},
            }
        )
        curr = normalize_prompt_snapshot(
            {
                "provider": "anthropic",
                "model_name": "claude-sonnet",
                "version_tag": "v2",
                "captured_at_iso": "2026-11-26T00:00:00Z",
                "sections": {"identity": "A2", "tools": "C"},
            }
        )
        diff = diff_prompt_snapshots(prev, curr)
        self.assertEqual(diff.severity, "breaking")
        self.assertEqual(diff.added_sections, ["tools"])
        self.assertEqual(diff.removed_sections, ["safety"])
        self.assertEqual(diff.modified_sections, ["identity"])

        payload = build_investigation_issue_payload(diff, curr)
        self.assertIsNotNone(payload)
        assert payload is not None
        self.assertTrue(payload.dry_run)
        self.assertIn("v2", payload.title)

    def test_additive_diff_without_removal(self) -> None:
        prev = normalize_prompt_snapshot(
            {
                "provider": "openai",
                "model_name": "gpt-5",
                "version_tag": "v1",
                "captured_at_iso": "2026-11-01T00:00:00Z",
                "sections": {"identity": "A"},
            }
        )
        curr = normalize_prompt_snapshot(
            {
                "provider": "openai",
                "model_name": "gpt-5",
                "version_tag": "v2",
                "captured_at_iso": "2026-11-26T00:00:00Z",
                "sections": {"identity": "A", "format": "JSON"},
            }
        )
        diff = diff_prompt_snapshots(prev, curr)
        self.assertEqual(diff.severity, "additive")

    def test_sample_dry_run_cli(self) -> None:
        script = Path(__file__).resolve().parent / "prompt_history_intake.py"
        proc = subprocess.run(
            [sys.executable, str(script), "--sample-dry-run", "--json"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(proc.stdout)
        self.assertTrue(data["ok"])
        self.assertEqual(data["diff"]["severity"], "additive")
        self.assertTrue(data["issue_payload"]["dry_run"])


if __name__ == "__main__":
    unittest.main()
