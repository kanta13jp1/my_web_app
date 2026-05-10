#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path

from check_codex_ui_qa_playbook import (
    REQUIRED_PLAYBOOK_TERMS,
    REQUIRED_TEMPLATE_TERMS,
    missing_terms,
    validate_repo,
)


class CodexUiQaPlaybookTest(unittest.TestCase):
    def test_repo_files_include_required_terms(self) -> None:
        root = Path(__file__).resolve().parents[1]

        self.assertEqual(validate_repo(root), [])

    def test_missing_terms_reports_absent_phrase(self) -> None:
        self.assertEqual(
            missing_terms("Codex in-app browser", ("Codex in-app browser", "HTTP 5xx")),
            ["HTTP 5xx"],
        )

    def test_term_lists_cover_playbook_and_template_contracts(self) -> None:
        self.assertIn("document.getAnimations", REQUIRED_PLAYBOOK_TERMS)
        self.assertIn("rights statement", REQUIRED_PLAYBOOK_TERMS)
        self.assertIn("npm run e2e:visual", REQUIRED_TEMPLATE_TERMS)
        self.assertIn("Changed routes/surfaces", REQUIRED_TEMPLATE_TERMS)


if __name__ == "__main__":
    unittest.main()

