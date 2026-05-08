#!/usr/bin/env python3
"""Unit tests for dev_cache_cleanup.py."""

from __future__ import annotations

import argparse
import os
import tempfile
import time
import unittest
from pathlib import Path

import dev_cache_cleanup as cleanup


def touch_old(path: Path, days: int) -> None:
    stamp = time.time() - days * 24 * 60 * 60
    os.utime(path, (stamp, stamp))


class DevCacheCleanupTest(unittest.TestCase):
    def test_stale_child_dirs_use_latest_mtime(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old_dir = root / "old"
            old_dir.mkdir()
            old_file = old_dir / "cache.bin"
            old_file.write_bytes(b"x")
            touch_old(old_file, 20)
            touch_old(old_dir, 20)

            mixed_dir = root / "mixed"
            mixed_dir.mkdir()
            fresh_file = mixed_dir / "fresh.bin"
            fresh_file.write_bytes(b"x")
            touch_old(mixed_dir, 20)

            stale = cleanup.stale_child_dirs_by_latest_mtime(root, 14)

        self.assertEqual(stale, [old_dir])

    def test_temp_deep_sweep_reports_metric_in_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            temp_root = Path(tmp)
            old_dir = temp_root / "old-installer"
            old_dir.mkdir()
            old_file = old_dir / "payload.bin"
            old_file.write_bytes(b"x" * 1024)
            touch_old(old_file, 20)
            touch_old(old_dir, 20)

            old_log = temp_root / "trace.log"
            old_log.write_bytes(b"x" * 1024)
            touch_old(old_log, 8)

            env_before = os.environ.get("TEMP")
            os.environ["TEMP"] = str(temp_root)
            args = argparse.Namespace(
                apply=False,
                max_runtime_sec=10,
                temp_subtree_age_days=14,
                temp_file_age_days=7,
            )
            try:
                actions = cleanup.collect_temp_deep_sweep_actions(args, temp_root)
                payload = cleanup.summary_payload(
                    argparse.Namespace(
                        apply=False,
                        include_worktrees=False,
                        tier18=False,
                        aggressive_cache_sweep=False,
                        tier19=True,
                        temp_deep_sweep=False,
                        cache_age_days=7,
                    ),
                    temp_root,
                    actions,
                )
            finally:
                if env_before is None:
                    os.environ.pop("TEMP", None)
                else:
                    os.environ["TEMP"] = env_before

        self.assertEqual(actions[0].status, "planned")
        self.assertEqual(actions[0].metric_key, "temp_subtree_14d_MB")
        self.assertGreaterEqual(payload["metrics"]["temp_subtree_14d_MB"], 0.0)

    def test_metric_values_prefers_actual_reclaim(self) -> None:
        actions = [
            cleanup.CleanupAction(
                name="n",
                kind="filesystem",
                target="t",
                status="success",
                reason="done",
                metric_key="tier_1_8_npm_MB",
                before_mb=10.0,
                reclaimed_mb=4.0,
            )
        ]

        self.assertEqual(cleanup.metric_values(actions), {"tier_1_8_npm_MB": 4.0})


if __name__ == "__main__":
    unittest.main()
