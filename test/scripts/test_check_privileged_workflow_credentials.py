#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.check_privileged_workflow_credentials import find_violations


class CheckPrivilegedWorkflowCredentialsTest(unittest.TestCase):
    def _messages(
        self, workflows: dict[str, str], environment_workflows: dict[str, list[str]]
    ) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / ".github" / "workflows"
            root.mkdir(parents=True)
            for name, contents in workflows.items():
                (root / name).write_text(contents, encoding="utf-8")
            manifest = {
                "schema_version": 1,
                "tracked_repository_secrets": [
                    "ANTHROPIC_API_KEY",
                    "SUPABASE_SERVICE_ROLE_KEY",
                ],
                "environments": {
                    name: {
                        "trust_boundary": "trusted main",
                        "purpose": "fixture",
                        "deployment_branch_policy": ["main"],
                        "deployment_tracking": False,
                        "least_privilege_targets": {
                            "ANTHROPIC_API_KEY": "fixture",
                            "SUPABASE_SERVICE_ROLE_KEY": "fixture",
                        },
                        "workflows": names,
                    }
                    for name, names in environment_workflows.items()
                },
            }
            manifest_path = Path(tmp) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            return [item.message for item in find_violations(root, manifest_path)]

    def test_accepts_environment_scoped_consumer_and_pr_exclusion(self) -> None:
        scheduled = """name: scheduled
on:
  schedule:
    - cron: '0 0 * * *'
jobs:
  run:
    environment:
      name: content-production
      deployment: false
    runs-on: ubuntu-latest
    steps:
      - env:
          ANTHROPIC_API_KEY: ${{ vars.PAID_AI_ENABLED == 'true' && secrets.ANTHROPIC_API_KEY || '' }}
        run: test -n "$ANTHROPIC_API_KEY"
"""
        pr_safe = """name: pr-safe
on:
  pull_request:
  schedule:
    - cron: '0 1 * * *'
jobs:
  run:
    if: github.event_name != 'pull_request'
    environment:
      name: operations-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: test -n "$SUPABASE_SERVICE_ROLE_KEY"
"""
        self.assertEqual(
            self._messages(
                {"scheduled.yml": scheduled, "pr-safe.yml": pr_safe},
                {
                    "content-production": ["scheduled.yml"],
                    "operations-production": ["pr-safe.yml"],
                },
            ),
            [],
        )

    def test_rejects_uninventoried_and_stale_consumers(self) -> None:
        workflow = """name: actual
on: workflow_dispatch
jobs:
  run:
    environment:
      name: content-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
    steps:
      - run: 'true'
"""
        messages = self._messages(
            {"actual.yml": workflow},
            {"content-production": ["stale.yml"]},
        )
        self.assertIn("tracked secret consumer is missing from the manifest", messages)
        self.assertIn(
            "manifest entry is stale because the workflow no longer consumes a tracked secret",
            messages,
        )

    def test_rejects_wrong_environment_and_internal_pr_exposure(self) -> None:
        workflow = """name: unsafe
on:
  pull_request:
jobs:
  run:
    environment:
      name: wrong-environment
      deployment: false
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: 'true'
"""
        messages = self._messages(
            {"unsafe.yml": workflow},
            {"operations-production": ["unsafe.yml"]},
        )
        self.assertTrue(
            any(
                "must declare environment `operations-production`" in item
                for item in messages
            )
        )
        self.assertTrue(
            any(
                "may expose a tracked secret to an internal pull_request" in item
                for item in messages
            )
        )

    def test_rejects_scalar_environment_without_deployment_opt_out(self) -> None:
        workflow = """name: noisy
on: workflow_dispatch
jobs:
  run:
    environment: operations-production
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: 'true'
"""
        messages = self._messages(
            {"noisy.yml": workflow},
            {"operations-production": ["noisy.yml"]},
        )
        self.assertIn("job `run` must set environment deployment to false", messages)

if __name__ == "__main__":
    unittest.main()
