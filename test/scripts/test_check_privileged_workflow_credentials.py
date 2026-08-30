#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.check_privileged_workflow_credentials import find_violations


class CheckPrivilegedWorkflowCredentialsTest(unittest.TestCase):
    @staticmethod
    def _exception() -> dict[str, object]:
        return {
            "status": "approved-temporary",
            "project_ref": "smmkxxavexumewbfaqpy",
            "reason": "fixture requires privileged access",
            "data_scope": "fixture table",
            "approver": "fixture-owner",
            "approval_basis": "fixture approval",
            "review_on": "2026-11-30",
            "rotation_owner": "fixture-owner",
            "replacement_blocker": "fixture scoped identity is unavailable",
            "rejected_alternatives": [
                "anon key cannot perform the operation",
                "secret key retains service-role privilege",
            ],
        }

    def _messages(
        self,
        workflows: dict[str, str],
        environment_workflows: dict[str, list[str]],
        workflow_job_environment_overrides: dict[str, dict[str, str]] | None = None,
        supabase_service_role_exceptions: dict[str, object] | None = None,
    ) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / ".github" / "workflows"
            root.mkdir(parents=True)
            for name, contents in workflows.items():
                (root / name).write_text(contents, encoding="utf-8")
            inferred_exceptions = {
                environment: self._exception()
                for environment, names in environment_workflows.items()
                if any(
                    "SUPABASE_SERVICE_ROLE_KEY" in workflows.get(name, "")
                    for name in names
                )
            }
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
                "workflow_job_environment_overrides": (
                    workflow_job_environment_overrides or {}
                ),
                "supabase_service_role_exceptions": (
                    inferred_exceptions
                    if supabase_service_role_exceptions is None
                    else supabase_service_role_exceptions
                ),
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

    def test_accepts_explicit_job_level_environment_overrides(self) -> None:
        workflow = """name: migration
on: workflow_dispatch
jobs:
  source:
    environment:
      name: source-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
    steps:
      - run: 'true'
  target:
    environment:
      name: target-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: 'true'
"""
        target_consumer = """name: target
on: workflow_dispatch
jobs:
  run:
    environment:
      name: target-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: 'true'
"""
        self.assertEqual(
            self._messages(
                {
                    "migration.yml": workflow,
                    "target-consumer.yml": target_consumer,
                },
                {
                    "source-production": ["migration.yml"],
                    "target-production": ["target-consumer.yml"],
                },
                {
                    "migration.yml": {
                        "source": "source-production",
                        "target": "target-production",
                    }
                },
                {"target-production": self._exception()},
            ),
            [],
        )

    def test_rejects_stale_job_level_environment_override(self) -> None:
        workflow = """name: migration
on: workflow_dispatch
jobs:
  source:
    environment:
      name: source-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
    steps:
      - run: 'true'
"""
        messages = self._messages(
            {"migration.yml": workflow},
            {"source-production": ["migration.yml"]},
            {
                "migration.yml": {
                    "source": "source-production",
                    "missing": "source-production",
                }
            },
        )
        self.assertIn(
            "job environment override is stale because the job does not consume a tracked secret",
            messages,
        )

    def test_requires_complete_service_role_exception(self) -> None:
        workflow = """name: privileged
on: workflow_dispatch
jobs:
  run:
    environment:
      name: operations-production
      deployment: false
    runs-on: ubuntu-latest
    env:
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    steps:
      - run: 'true'
"""
        missing = self._messages(
            {"privileged.yml": workflow},
            {"operations-production": ["privileged.yml"]},
            supabase_service_role_exceptions={},
        )
        self.assertIn(
            "active SUPABASE_SERVICE_ROLE_KEY use requires an approved temporary exception",
            missing,
        )

        incomplete = self._messages(
            {"privileged.yml": workflow},
            {"operations-production": ["privileged.yml"]},
            supabase_service_role_exceptions={
                "operations-production": {"status": "approved-temporary"}
            },
        )
        self.assertIn(
            "service-role exception field `reason` is required",
            incomplete,
        )
        self.assertIn(
            "service-role exception must document at least two rejected alternatives",
            incomplete,
        )

if __name__ == "__main__":
    unittest.main()
