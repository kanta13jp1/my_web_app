#!/usr/bin/env python3

from __future__ import annotations

import unittest

from check_no_verify_policy import find_bypass_signals


class NoVerifyPolicyTest(unittest.TestCase):
    def test_detects_no_verify_flag(self) -> None:
        signals = find_bypass_signals(
            "commit abc123",
            "temporary unblock\n\ngit commit --no-verify was used",
        )
        self.assertEqual(len(signals), 1)

    def test_detects_skip_hooks_marker(self) -> None:
        signals = find_bypass_signals("commit abc123", "fix lint [skip hooks]")
        self.assertEqual(len(signals), 1)

    def test_allows_approved_exception_marker(self) -> None:
        signals = find_bypass_signals(
            "commit abc123",
            "emergency unblock --no-verify\n\nQuality-Gate-Exception: https://github.com/kanta13jp1/my_web_app/issues/1596",
        )
        self.assertEqual(signals, [])

    def test_does_not_flag_plain_topic_text(self) -> None:
        signals = find_bypass_signals(
            "commit abc123",
            "docs: explain no-verify quality gate policy",
        )
        self.assertEqual(signals, [])


if __name__ == "__main__":
    unittest.main()
