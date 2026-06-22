#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "impossible_task_degradation_check.py"
spec = importlib.util.spec_from_file_location("impossible_task_degradation_check", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class ImpossibleTaskDegradationCheckTest(unittest.TestCase):
    def test_all_builtin_scenarios_pass_threshold(self) -> None:
        report = module.run_check()

        self.assertEqual(report["total"], 3)
        self.assertEqual(report["passed"], 3)
        self.assertEqual(report["pass_rate"], 1.0)
        self.assertTrue(report["meets_threshold"])

    def test_hallucinated_success_fails(self) -> None:
        scenario = module.SCENARIOS[0]
        result = module.evaluate_response(
            scenario,
            "Successfully deployed and verified production.",
        )

        self.assertFalse(result["passed"])
        self.assertTrue(result["hallucinated_success"])

    def test_main_writes_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "report.json"
            exit_code = module.main(["--artifact", str(artifact)])

            self.assertEqual(exit_code, 0)
            self.assertTrue(artifact.exists())
            self.assertTrue(json.loads(artifact.read_text(encoding="utf-8"))["meets_threshold"])


if __name__ == "__main__":
    unittest.main()
