#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import unittest

from quality_gate import flutter_vm_test_concurrency, full_commands


class QualityGateTest(unittest.TestCase):
    def test_pre_push_does_not_repeat_the_full_ci_gate(self) -> None:
        root = Path(__file__).resolve().parents[1]
        lefthook = (root / "lefthook.yml").read_text(encoding="utf-8")

        self.assertNotIn("pre-push:", lefthook)
        self.assertNotIn("quality_gate.py --full", lefthook)

    def test_vm_tests_keep_coverage_with_bounded_concurrency(self) -> None:
        root = Path(__file__).resolve().parents[1]
        command = next(
            item for item in full_commands(root) if item.name == "flutter vm tests"
        )

        self.assertEqual(
            command.args,
            [
                "flutter",
                "test",
                "--coverage",
                f"--concurrency={flutter_vm_test_concurrency()}",
            ],
        )
        self.assertEqual(flutter_vm_test_concurrency("nt"), 1)
        self.assertEqual(flutter_vm_test_concurrency("posix"), 2)

        workflow = (root / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "run: flutter test --coverage --concurrency=2",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
