#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from check_ai_tool_update_routing import REQUIRED_MARKERS, missing_markers


class AiToolUpdateRoutingTest(unittest.TestCase):
    def test_repo_docs_include_required_markers(self) -> None:
        root = Path(__file__).resolve().parents[1]

        self.assertEqual(missing_markers(root), [])

    def test_missing_file_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = missing_markers(Path(tmp))

        self.assertTrue(any("missing file" in item for item in missing))

    def test_contract_tracks_all_three_docs(self) -> None:
        self.assertEqual(
            set(REQUIRED_MARKERS),
            {
                "docs/AI_FALLBACK_RUNBOOK.md",
                "docs/DEV_PROCESS_MULTI_AI.md",
                ".github/agents/README.md",
            },
        )


if __name__ == "__main__":
    unittest.main()
