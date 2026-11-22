"""Regression tests ensuring Notion auto-sync schedules and watch targets stay disabled."""

from __future__ import annotations

import importlib.util
import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


def _load_schedule_targets():
    script_path = ROOT / "scripts" / "schedule_resilience_watch.py"
    spec = importlib.util.spec_from_file_location("schedule_resilience_watch", script_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {script_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["schedule_resilience_watch"] = module
    spec.loader.exec_module(module)
    return {target.key: target for target in module.TARGETS}


class NotionSyncSuspensionWorkflowTests(unittest.TestCase):
    def test_notion_sync_workflow_has_no_schedule_and_keeps_manual_dispatch(self) -> None:
        text = (WORKFLOWS / "notion-sync.yml").read_text(encoding="utf-8")
        on_match = re.search(r"(?m)^on:\n((?:  .*\n|\n)*?)(?=^[A-Za-z0-9_-]+:|\Z)", text)
        self.assertIsNotNone(on_match, "Expected top-level 'on:' block in notion-sync.yml")
        on_block = on_match.group(1)
        self.assertIsNone(re.search(r"(?m)^  schedule:", on_block))
        self.assertNotIn("cron:", on_block)
        self.assertIsNotNone(re.search(r"(?m)^  workflow_dispatch:", on_block))
        self.assertIn("wbs-automation-production", text)

    def test_issue_to_wbs_no_longer_invokes_notion_sync(self) -> None:
        text = (WORKFLOWS / "issue-to-wbs.yml").read_text(encoding="utf-8")
        self.assertNotIn("notion.sync_wbs", text)
        self.assertNotIn("Sync Notion WBS mirror", text)

    def test_schedule_resilience_watch_excludes_notion_sync(self) -> None:
        targets = _load_schedule_targets()
        self.assertNotIn("notion-sync", targets)
        self.assertIn("deploy-prod", targets)
        self.assertIn("daily-report", targets)


if __name__ == "__main__":
    unittest.main()
