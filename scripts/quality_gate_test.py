#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import unittest

from quality_gate import full_commands


class QualityGateTest(unittest.TestCase):
    def test_vm_tests_keep_coverage_with_bounded_concurrency(self) -> None:
        root = Path(__file__).resolve().parents[1]
        command = next(
            item for item in full_commands(root) if item.name == "flutter vm tests"
        )

        self.assertEqual(
            command.args,
            ["flutter", "test", "--coverage", "--concurrency=2"],
        )

        workflow = (root / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "run: flutter test --coverage --concurrency=2",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
