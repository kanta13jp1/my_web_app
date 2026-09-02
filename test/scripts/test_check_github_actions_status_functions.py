#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_status_functions import (
    find_violations,
    workflow_files,
)


class CheckGithubActionsStatusFunctionsTest(unittest.TestCase):
    def test_allows_status_function_in_step_if(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - if: always() && !cancelled()\n"
                "        run: echo ok\n",
                encoding="utf-8",
            )

            self.assertEqual(find_violations(workflow_files(workflows)), [])

    def test_rejects_status_function_in_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - env:\n"
                "          JOB_CANCELLED: ${{ cancelled() }}\n"
                "        run: echo invalid\n",
                encoding="utf-8",
            )

            self.assertEqual(
                find_violations(workflow_files(workflows)),
                [(path, 5, "JOB_CANCELLED: ${{ cancelled() }}")],
            )

    def test_rejects_status_function_in_run_expression(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - run: echo '${{ failure() }}'\n",
                encoding="utf-8",
            )

            self.assertEqual(
                find_violations(workflow_files(workflows)),
                [(path, 4, "- run: echo '${{ failure() }}'")],
            )


if __name__ == "__main__":
    unittest.main()
