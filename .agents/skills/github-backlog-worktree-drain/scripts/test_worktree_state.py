#!/usr/bin/env python3
"""Deterministic tests for worktree_state.py."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("worktree_state.py")


def run(command: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and proc.returncode != 0:
        raise AssertionError(proc.stderr or proc.stdout)
    return proc


class WorktreeStateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "repo"
        self.root.mkdir()
        run(["git", "init", "-b", "main"], self.root)
        run(["git", "config", "user.name", "Test User"], self.root)
        run(["git", "config", "user.email", "test@example.com"], self.root)
        (self.root / "tracked.txt").write_text("initial\n", encoding="utf-8")
        run(["git", "add", "tracked.txt"], self.root)
        run(["git", "commit", "-m", "initial"], self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def cli(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return run([sys.executable, str(SCRIPT), *args], self.root, check=check)

    def test_audit_reports_clean_and_dirty_paths(self) -> None:
        clean = self.cli(
            "audit",
            "--repo",
            str(self.root),
            "--target",
            str(self.root),
            "--base",
            "main",
        )
        payload = json.loads(clean.stdout)
        self.assertTrue(payload["worktrees"][0]["clean"])
        self.assertTrue(payload["worktrees"][0]["primary"])

        (self.root / "untracked.txt").write_text("dirty\n", encoding="utf-8")
        dirty = self.cli(
            "audit",
            "--repo",
            str(self.root),
            "--target",
            str(self.root),
            "--base",
            "main",
        )
        payload = json.loads(dirty.stdout)
        self.assertFalse(payload["worktrees"][0]["clean"])
        self.assertIn("untracked.txt", payload["worktrees"][0]["dirty_paths"])

    def test_checkpoint_round_trip_and_secret_rejection(self) -> None:
        sensitive_path = self.root / "token=hidden-value.txt"
        sensitive_path.write_text("fixture\n", encoding="utf-8")
        saved = self.cli(
            "checkpoint",
            "set",
            "--repo",
            str(self.root),
            "--base",
            "main",
            "--phase",
            "scope",
            "--status",
            "in_progress",
            "--summary",
            "Scope confirmed",
            "--evidence",
            "targeted test passed",
            "--next-action",
            "Commit the scoped diff",
        )
        payload = json.loads(saved.stdout)
        self.assertTrue(Path(payload["saved"]).exists())
        self.assertNotIn("hidden-value", saved.stdout)
        self.assertIn("<redacted-sensitive-value>", saved.stdout)
        shown = self.cli(
            "checkpoint",
            "show",
            "--repo",
            str(self.root),
            "--key",
            "main",
        )
        self.assertEqual(json.loads(shown.stdout)["status"], "in_progress")

        rejected = self.cli(
            "checkpoint",
            "set",
            "--repo",
            str(self.root),
            "--base",
            "main",
            "--phase",
            "pause",
            "--status",
            "paused",
            "--summary",
            "token=do-not-store",
            "--next-action",
            "Resume",
            check=False,
        )
        self.assertEqual(rejected.returncode, 2)
        self.assertIn("secret", rejected.stderr)

    def test_cleanup_requires_non_primary_clean_merged_worktree(self) -> None:
        worktree = Path(self.temporary.name) / "feature-worktree"
        run(
            ["git", "worktree", "add", "-b", "feature", str(worktree), "main"],
            self.root,
        )
        (worktree / "feature.txt").write_text("feature\n", encoding="utf-8")
        run(["git", "add", "feature.txt"], worktree)
        run(["git", "commit", "-m", "feature"], worktree)
        head = run(["git", "rev-parse", "HEAD"], worktree).stdout.strip()
        run(["git", "merge", "--no-ff", "feature", "-m", "merge feature"], self.root)

        safe = self.cli(
            "cleanup-check",
            "--repo",
            str(self.root),
            "--worktree",
            str(worktree),
            "--base",
            "main",
            "--expected-head",
            head,
        )
        self.assertTrue(json.loads(safe.stdout)["safe"])

        (worktree / "dirty.txt").write_text("dirty\n", encoding="utf-8")
        unsafe = self.cli(
            "cleanup-check",
            "--repo",
            str(self.root),
            "--worktree",
            str(worktree),
            "--base",
            "main",
            check=False,
        )
        self.assertEqual(unsafe.returncode, 3)
        self.assertFalse(json.loads(unsafe.stdout)["safe"])


if __name__ == "__main__":
    unittest.main()
