#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_script_injection import (
    find_violations,
    workflow_files,
)


class CheckGithubActionsScriptInjectionTest(unittest.TestCase):
    def _violations(self, workflow: str) -> list[tuple[Path, int, str]]:
        with tempfile.TemporaryDirectory() as tmp:
            workflows = Path(tmp) / ".github" / "workflows"
            workflows.mkdir(parents=True)
            path = workflows / "ci.yml"
            path.write_text(workflow, encoding="utf-8")
            violations = find_violations(workflow_files(workflows))
            return [(Path(item[0].name), item[1], item[2]) for item in violations]

    def test_rejects_untrusted_values_in_block_run(self) -> None:
        workflow = (
            "jobs:\n"
            "  test:\n"
            "    steps:\n"
            "      - run: |\n"
            "          echo '${{ github.event.pull_request.title }}'\n"
            "          echo '${{ inputs.title }}'\n"
            "          echo '${{ steps.meta.outputs.title }}'\n"
            "          echo '${{ github.ref_name }}'\n"
        )

        self.assertEqual(
            self._violations(workflow),
            [
                (Path("ci.yml"), 5, "echo '${{ github.event.pull_request.title }}'"),
                (Path("ci.yml"), 6, "echo '${{ inputs.title }}'"),
                (Path("ci.yml"), 7, "echo '${{ steps.meta.outputs.title }}'"),
                (Path("ci.yml"), 8, "echo '${{ github.ref_name }}'"),
            ],
        )

    def test_rejects_workflow_input_in_inline_run(self) -> None:
        workflow = "jobs:\n  test:\n    steps:\n      - run: echo '${{ inputs.slug }}'\n"

        self.assertEqual(
            self._violations(workflow),
            [(Path("ci.yml"), 4, "- run: echo '${{ inputs.slug }}'")],
        )

    def test_allows_quote_safe_env_handoff_and_non_string_runtime_values(self) -> None:
        workflow = (
            "jobs:\n"
            "  test:\n"
            "    steps:\n"
            "      - if: ${{ github.event.pull_request.title != '' }}\n"
            "        env:\n"
            "          TITLE: ${{ github.event.pull_request.title }}\n"
            "        run: |\n"
            "          printf '%s\\n' \"$TITLE\"\n"
            "          echo '${{ github.sha }}'\n"
            "          echo '${{ steps.test.outcome }}'\n"
        )

        self.assertEqual(self._violations(workflow), [])


if __name__ == "__main__":
    unittest.main()
