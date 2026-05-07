#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from worktree_registry import (
    RegistryEntry,
    detect_registry_conflicts,
    load_registry,
    normalize_paths,
    overlap_set,
    paths_overlap,
    save_registry,
    upsert_entry,
)


class WorktreeRegistryTest(unittest.TestCase):
    def test_path_overlap_matches_exact_files_and_parent_dirs(self) -> None:
        self.assertTrue(paths_overlap("docs", "docs/WORKTREE_REGISTRY.md"))
        self.assertTrue(paths_overlap("scripts/worktree_registry.py", "scripts/worktree_registry.py"))
        self.assertFalse(paths_overlap("docs", "scripts/worktree_registry.py"))

    def test_overlap_set_deduplicates_normalized_paths(self) -> None:
        overlaps = overlap_set(
            ["docs\\WORKTREE_REGISTRY.md", "scripts/worktree_registry.py"],
            ["docs", "lib"],
        )

        self.assertEqual(overlaps, ["docs/WORKTREE_REGISTRY.md"])

    def test_registry_upsert_replaces_same_instance_issue_worktree(self) -> None:
        first = RegistryEntry(
            instance="codex1",
            owner="Codex #1",
            issue="1574",
            worktree="/tmp/worktree",
            branch="codex/old",
            paths=["docs"],
            status="active",
            updated_at="2026-05-07T00:00:00+00:00",
        )
        second = RegistryEntry(
            instance="codex1",
            owner="Codex #1",
            issue="1574",
            worktree="/tmp/worktree",
            branch="codex/new",
            paths=["scripts"],
            status="active",
            updated_at="2026-05-07T00:01:00+00:00",
        )

        entries = upsert_entry(upsert_entry([], first), second)

        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0].branch, "codex/new")
        self.assertEqual(entries[0].paths, ["scripts"])

    def test_detects_active_registry_path_conflict(self) -> None:
        entry = RegistryEntry(
            instance="claude1",
            owner="Claude Code #1",
            issue="999",
            worktree="/tmp/claude",
            branch="claude/task",
            paths=["docs"],
            status="active",
            updated_at="2026-05-07T00:00:00+00:00",
        )

        events = detect_registry_conflicts(
            [entry],
            ["docs/WORKTREE_REGISTRY.md"],
            instance="codex1",
            issue="1574",
        )

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].level, "High")
        self.assertEqual(events[0].kind, "registry-path-overlap")

    def test_registry_round_trip(self) -> None:
        entry = RegistryEntry(
            instance="codex1",
            owner="Codex #1",
            issue="1574",
            worktree="/tmp/codex",
            branch="codex/task",
            paths=normalize_paths(["docs\\WORKTREE_REGISTRY.md"]),
            status="active",
            updated_at="2026-05-07T00:00:00+00:00",
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry.json"
            save_registry(path, [entry])
            loaded = load_registry(path)

        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0].paths, ["docs/WORKTREE_REGISTRY.md"])


if __name__ == "__main__":
    unittest.main()
