from __future__ import annotations

import unittest

from scripts.check_protected_files_nonempty import (
    FileState,
    find_emptied_files,
    is_protected,
)


class IsProtectedTest(unittest.TestCase):
    def test_workflow_and_claude_trees_are_protected(self) -> None:
        self.assertTrue(is_protected(".github/workflows/ci.yml"))
        self.assertTrue(is_protected(".claude/settings.json"))
        self.assertTrue(is_protected(".claude/commands/wrap-up.md"))

    def test_other_trees_are_not_protected(self) -> None:
        # Emptying these is loud: the build or the script itself fails.
        self.assertFalse(is_protected("lib/main.dart"))
        self.assertFalse(is_protected("scripts/sync_inject_rules.py"))
        self.assertFalse(is_protected("docs/GROWTH_STRATEGY_ROADMAP.md"))
        self.assertFalse(is_protected(".github/dependabot.yml"))


class FindEmptiedFilesTest(unittest.TestCase):
    def test_flags_workflow_emptied_from_non_empty(self) -> None:
        states = [FileState(".github/workflows/ci.yml", base_size=17413, head_size=0)]

        findings = find_emptied_files(states)

        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].path, ".github/workflows/ci.yml")
        self.assertEqual(findings[0].base_size, 17413)

    def test_flags_claude_config_emptied_from_non_empty(self) -> None:
        states = [FileState(".claude/settings.json", base_size=12371, head_size=0)]

        self.assertEqual(len(find_emptied_files(states)), 1)

    def test_flags_empty_file_shadowing_real_upstream_content(self) -> None:
        # The feature-releases-sync.yml case: absent from the branch's own history
        # but present with content on main, so it arrives as an *addition* of an
        # empty file. Comparing against the merge base would miss this entirely;
        # comparing against the base tip catches it.
        states = [
            FileState(".github/workflows/feature-releases-sync.yml", base_size=1299, head_size=0)
        ]

        self.assertEqual(len(find_emptied_files(states)), 1)

    def test_allows_deletion(self) -> None:
        # Retiring a workflow is legitimate; only emptying it in place is not.
        states = [FileState(".github/workflows/old.yml", base_size=5000, head_size=None)]

        self.assertEqual(find_emptied_files(states), [])

    def test_allows_new_empty_file_with_no_upstream_content(self) -> None:
        states = [FileState(".claude/placeholder.txt", base_size=None, head_size=0)]

        self.assertEqual(find_emptied_files(states), [])

    def test_allows_file_already_empty_upstream(self) -> None:
        # Tracked 0-byte markers such as .gitkeep stay 0 bytes on both sides.
        states = [FileState(".claude/keep/.gitkeep", base_size=0, head_size=0)]

        self.assertEqual(find_emptied_files(states), [])

    def test_allows_ordinary_edit(self) -> None:
        states = [FileState(".github/workflows/ci.yml", base_size=17413, head_size=16775)]

        self.assertEqual(find_emptied_files(states), [])

    def test_ignores_emptied_file_outside_protected_trees(self) -> None:
        states = [FileState("lib/main.dart", base_size=4200, head_size=0)]

        self.assertEqual(find_emptied_files(states), [])

    def test_reports_every_emptied_file(self) -> None:
        # The 2026-07-21 incident emptied eight files at once.
        states = [
            FileState(f".github/workflows/w{index}.yml", base_size=1000, head_size=0)
            for index in range(6)
        ] + [
            FileState(".claude/settings.json", base_size=12371, head_size=0),
            FileState(".claude/commands/wrap-up.md", base_size=11113, head_size=0),
        ]

        self.assertEqual(len(find_emptied_files(states)), 8)


if __name__ == "__main__":
    unittest.main()
