#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_python_inline import find_violations, workflow_files


class CheckGithubActionsPythonInlineTest(unittest.TestCase):
    def test_allows_single_line_inline_python(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - run: python3 -c \"print(1)\"\n",
                encoding="utf-8",
            )

            self.assertEqual(find_violations(workflow_files(workflows)), [])

    def test_rejects_multiline_inline_python_opening_quote(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - run: |\n"
                "          python3 -c \"\n"
                "          print(1)\n"
                "          \"\n",
                encoding="utf-8",
            )

            self.assertEqual(
                find_violations(workflow_files(workflows)),
                [(path, 5, 'python3 -c "')],
            )

    def test_allows_heredoc_python(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - run: |\n"
                "          python3 <<'PY'\n"
                "          print(1)\n"
                "          PY\n",
                encoding="utf-8",
            )

            self.assertEqual(find_violations(workflow_files(workflows)), [])


if __name__ == "__main__":
    unittest.main()
