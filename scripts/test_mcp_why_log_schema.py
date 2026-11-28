#!/usr/bin/env python3
"""Unit tests for scripts/check_mcp_why_log_schema.py (#2814)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_mcp_why_log_schema as validator  # noqa: E402


class McpWhyLogSchemaTest(unittest.TestCase):
    def test_repo_schema_file_is_valid(self) -> None:
        repo_root = Path(__file__).resolve().parent.parent
        schema_path = (
            repo_root / "docs" / "schemas" / "mcp_reasoning_context.schema.json"
        )
        res = validator.validate_schema_file(schema_path)
        self.assertTrue(res.valid, res.errors)

    def test_validate_reasoning_context_accepts_valid_and_rejects_bad(
        self,
    ) -> None:
        valid_payload = {
            "availableTools": ["supabase_query", "github_issue_view"],
            "selectedTool": "supabase_query",
            "reasoningWhy": "Inspect current row count before planning.",
            "promptSummary": "Check table rows.",
            "serverName": "supabase-mcp",
            "timestamp": "2026-11-26T10:00:00Z",
        }
        self.assertTrue(
            validator.validate_reasoning_context(valid_payload).valid,
        )

        bad_tool = dict(valid_payload, selectedTool="unknown_tool")
        bad_res = validator.validate_reasoning_context(bad_tool)
        self.assertFalse(bad_res.valid)
        self.assertIn("not in availableTools", bad_res.errors[0])

        bad_ts = dict(valid_payload, timestamp="not-a-timestamp")
        self.assertFalse(validator.validate_reasoning_context(bad_ts).valid)

    def test_cli_validates_schema_and_sample_json(self) -> None:
        repo_root = Path(__file__).resolve().parent.parent
        schema_path = (
            repo_root / "docs" / "schemas" / "mcp_reasoning_context.schema.json"
        )
        with tempfile.TemporaryDirectory() as tmp:
            sample_path = Path(tmp) / "sample.json"
            sample_path.write_text(
                json.dumps(
                    {
                        "availableTools": ["read_board"],
                        "selectedTool": "read_board",
                        "reasoningWhy": "Read latest status.",
                        "promptHash": "sha256:1234",
                        "serverName": "swarm-mcp",
                        "timestamp": "2026-11-26T10:15:00Z",
                    }
                ),
                encoding="utf-8",
            )
            rc = validator.main(
                [
                    "--schema",
                    str(schema_path),
                    "--sample",
                    str(sample_path),
                ]
            )
            self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
