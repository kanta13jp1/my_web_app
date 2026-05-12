#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_no_verify_bypass import event_range, find_bypass_markers


class NoVerifyBypassTest(unittest.TestCase):
    def test_allows_normal_commit_message(self) -> None:
        self.assertEqual(find_bypass_markers("fix: update CI gate"), [])

    def test_detects_quality_gate_bypass_trailer(self) -> None:
        markers = find_bypass_markers("Quality-Gate-Bypass: pre-commit-not-run")

        self.assertTrue(markers)

    def test_detects_quality_gate_exception_trailer(self) -> None:
        markers = find_bypass_markers("Quality-Gate-Exception: emergency")

        self.assertTrue(markers)

    def test_detects_no_verify_command_text(self) -> None:
        markers = find_bypass_markers("used git commit --no-verify during emergency")

        self.assertTrue(markers)

    def test_derives_pull_request_range(self) -> None:
        payload = {
            "pull_request": {
                "base": {"sha": "base123"},
                "head": {"sha": "head456"},
            }
        }

        self.assertEqual(event_range(payload), "base123..head456")


if __name__ == "__main__":
    unittest.main()
