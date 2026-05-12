#!/usr/bin/env python3
"""Unit tests for worktree_cleanup.py."""

from __future__ import annotations

import os
import tempfile
import time
import unittest
from pathlib import Path

import worktree_cleanup as cleanup


class WorktreeCleanupTest(unittest.TestCase):
    def test_parse_worktree_list_marks_locked_entries(self) -> None:
        raw = (
            "worktree C:/repo\n"
            "HEAD abc\n"
            "branch refs/heads/main\n"
            "\n"
            "worktree C:/repo/.claude/worktrees/stale\n"
            "HEAD def\n"
            "branch refs/heads/feature/stale\n"
            "locked\n"
            "\n"
        )

        entries = cleanup.parse_worktree_list(raw)

        self.assertFalse(entries[0].locked)
        self.assertTrue(entries[1].locked)

    def test_branch_prefix_protection_matches_codex_prefix(self) -> None:
        self.assertTrue(cleanup.has_branch_prefix("codex/task", ("codex/",)))
        self.assertFalse(cleanup.has_branch_prefix("feature/task", ("codex/",)))

    def test_worktree_idle_days_uses_directory_mtime(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            stamp = time.time() - 9 * 24 * 60 * 60
            os.utime(path, (stamp, stamp))

            idle_days = cleanup.worktree_idle_days(path, now=time.time())

        self.assertGreaterEqual(idle_days, 8.9)

    def test_summary_payload_includes_reclaimed_mb_for_dry_run(self) -> None:
        decision = cleanup.WorktreeDecision(
            path="C:/repo/.claude/worktrees/stale",
            branch="feature/stale",
            decision="PRUNE",
            reason="merged",
            head="abc",
            size_mb=123.4,
        )

        payload = cleanup.summary_payload([decision], applied=False, base_ref="origin/main")

        self.assertEqual(payload["reclaimed_mb"], 123.4)


if __name__ == "__main__":
    unittest.main()
