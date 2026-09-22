#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.check_github_actions_security_policy import (
    find_violations,
    workflow_files,
)


class CheckGithubActionsSecurityPolicyTest(unittest.TestCase):
    def _messages(self, workflows: dict[str, str]) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / ".github" / "workflows"
            root.mkdir(parents=True)
            for name, contents in workflows.items():
                (root / name).write_text(contents, encoding="utf-8")
            return [item.message for item in find_violations(workflow_files(root))]

    def test_accepts_hardened_job_and_reusable_call(self) -> None:
        workflow = """name: actionlint
on: pull_request
permissions: {}
concurrency:
  group: policy-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  lint:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789
      - run: actionlint
  shared:
    permissions:
      contents: read
    uses: ./.github/workflows/shared.yml
"""

        self.assertEqual(self._messages({"policy.yml": workflow}), [])

    def test_reports_each_required_control(self) -> None:
        workflow = """name: unsafe
on: pull_request
permissions:
  contents: write
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
"""

        messages = self._messages({"unsafe.yml": workflow})

        self.assertIn("missing workflow concurrency", messages)
        self.assertIn(
            "workflow-level permissions must be exactly `permissions: {}`", messages
        )
        self.assertIn("job `test` must declare permissions", messages)
        self.assertIn("job `test` must declare timeout-minutes", messages)
        self.assertIn(
            "external action must use a full commit SHA: actions/checkout@v7", messages
        )
        self.assertIn("no GitHub Actions workflow runs actionlint", messages)

    def test_rejects_missing_cancel_and_accepts_local_or_docker_actions(self) -> None:
        workflow = """name: actionlint
on: push
permissions: {}
concurrency:
  group: one-at-a-time
jobs:
  test:
    permissions: {}
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: ./.github/actions/local
      - uses: docker://rhysd/actionlint:1.7.7
      - run: actionlint
"""

        self.assertEqual(
            self._messages({"policy.yaml": workflow}),
            ["concurrency must set cancel-in-progress"],
        )


if __name__ == "__main__":
    unittest.main()
