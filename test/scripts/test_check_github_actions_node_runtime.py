#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_node_runtime import find_violations


class CheckGithubActionsNodeRuntimeTest(unittest.TestCase):
    def _check(self, workflow: str) -> tuple[list[str], int]:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ci.yml"
            path.write_text(workflow, encoding="utf-8")
            violations, checked = find_violations([path])
            return [item.split(": ", 1)[1] for item in violations], checked

    def test_accepts_pinned_sha_with_supported_version_comment(self) -> None:
        violations, checked = self._check(
            "steps:\n"
            "  - uses: actions/checkout@0123456789012345678901234567890123456789 # v7\n"
            "  - uses: actions/github-script@abcdefabcdefabcdefabcdefabcdefabcdefabcd # v9\n"
        )

        self.assertEqual(violations, [])
        self.assertEqual(checked, 2)

    def test_rejects_old_major_even_when_sha_is_pinned(self) -> None:
        violations, checked = self._check(
            "steps:\n"
            "  - uses: actions/checkout@0123456789012345678901234567890123456789 # v4\n"
        )

        self.assertEqual(checked, 1)
        self.assertIn("must be >= v6", violations[0])

    def test_requires_version_comment_for_runtime_sensitive_sha(self) -> None:
        violations, checked = self._check(
            "steps:\n"
            "  - uses: actions/checkout@0123456789012345678901234567890123456789\n"
        )

        self.assertEqual(checked, 1)
        self.assertIn("must include a trailing version comment", violations[0])


if __name__ == "__main__":
    unittest.main()
