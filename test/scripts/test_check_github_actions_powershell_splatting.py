#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_powershell_splatting import (
    find_violations,
    workflow_files,
)


class CheckGithubActionsPowershellSplattingTest(unittest.TestCase):
    def test_allows_named_hashtable_splat(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - shell: pwsh\n"
                "        run: ./smoke.ps1 @smokeParams\n",
                encoding="utf-8",
            )

            self.assertEqual(find_violations(workflow_files(workflows)), [])

    def test_rejects_automatic_args_splat(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - shell: pwsh\n"
                "        run: ./smoke.ps1 @args\n",
                encoding="utf-8",
            )

            self.assertEqual(
                find_violations(workflow_files(workflows)),
                [(path, 5, "run: ./smoke.ps1 @args")],
            )

    def test_rejects_automatic_args_splat_case_insensitively(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(
                "jobs:\n"
                "  test:\n"
                "    steps:\n"
                "      - shell: pwsh\n"
                "        run: ./smoke.ps1 @Args\n",
                encoding="utf-8",
            )

            self.assertEqual(
                find_violations(workflow_files(workflows)),
                [(path, 5, "run: ./smoke.ps1 @Args")],
            )


if __name__ == "__main__":
    unittest.main()
