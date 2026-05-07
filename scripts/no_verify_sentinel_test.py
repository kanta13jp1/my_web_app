#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from no_verify_sentinel import (
    assert_pre_commit,
    has_git_operation_state,
    read_stamp,
    stamp_matches,
    write_stamp,
)


class NoVerifySentinelTest(unittest.TestCase):
    def test_stamp_matches_current_tree_and_age(self) -> None:
        payload = {"tree": "abc123", "created_at": 100.0}

        self.assertTrue(stamp_matches(payload, "abc123", now=120.0))

    def test_rejects_stale_stamp(self) -> None:
        payload = {"tree": "abc123", "created_at": 100.0}

        self.assertFalse(stamp_matches(payload, "abc123", now=500.0))

    def test_rejects_different_tree(self) -> None:
        payload = {"tree": "abc123", "created_at": 100.0}

        self.assertFalse(stamp_matches(payload, "def456", now=120.0))

    def test_round_trips_stamp_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stamp.json"
            write_stamp(path, "tree789", now=100.0)

            self.assertEqual(read_stamp(path), {"created_at": 100.0, "tree": "tree789"})

    def test_allows_git_sequencer_operations(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "rebase-merge").mkdir()

            self.assertTrue(has_git_operation_state(lambda name: root / name))

    def test_assert_pre_commit_requires_matching_stamp(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            stamp = Path(temp_dir) / "stamp.json"
            with (
                patch("no_verify_sentinel.has_git_operation_state", return_value=False),
                patch("no_verify_sentinel.stamp_path", return_value=stamp),
                patch("no_verify_sentinel.current_tree", return_value="tree123"),
            ):
                self.assertEqual(assert_pre_commit(), 1)

                write_stamp(stamp, "tree123")

                self.assertEqual(assert_pre_commit(), 0)


if __name__ == "__main__":
    unittest.main()
