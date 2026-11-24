#!/usr/bin/env python3
"""Unit tests for deterministic stage-gate validation (#2593)."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from validate_stage_gate_transition import (  # noqa: E402
    extract_stage_from_labels,
    validate_stage_transition,
)


class StageGateTransitionValidationTests(unittest.TestCase):
    def test_valid_sequential_intake_to_design(self) -> None:
        result = validate_stage_transition(
            current_stage="intake",
            target_stage="design",
            title="[notebooklm:4d9d5d89:1] Stage-gate workflow",
            source_ref="#2593",
            body="",
        )
        self.assertTrue(result.valid)
        self.assertEqual(result.errors, ())

    def test_rejects_stage_skip_and_backward_transition(self) -> None:
        skipped = validate_stage_transition(
            current_stage="intake",
            target_stage="verification",
            title="Task A",
            source_ref="#101",
            body="- [ ] verified",
        )
        self.assertFalse(skipped.valid)
        self.assertIn("Cannot skip stage", skipped.errors[0])

        backward = validate_stage_transition(
            current_stage="implementation",
            target_stage="design",
            title="Task A",
            source_ref="#101",
            body="- [x] done",
        )
        self.assertFalse(backward.valid)
        self.assertIn("must advance beyond", backward.errors[0])

    def test_requires_title_source_ref_and_checklist_for_implementation(self) -> None:
        res = validate_stage_transition(
            current_stage="design",
            target_stage="implementation",
            title=" ",
            source_ref="",
            body="plain description without checkboxes",
        )
        self.assertFalse(res.valid)
        self.assertEqual(len(res.errors), 3)

        valid_impl = validate_stage_transition(
            current_stage="design",
            target_stage="implementation",
            title="Stage-gate workflow",
            source_ref="#2593",
            body="- [ ] Add RLS policy\n- [x] Document stages",
        )
        self.assertTrue(valid_impl.valid)
        self.assertEqual(valid_impl.checklist_items, 2)

    def test_extract_stage_from_labels(self) -> None:
        self.assertEqual(
            extract_stage_from_labels(
                ["enhancement", "stage:implementation", "stage:design"]
            ),
            "implementation",
        )
        self.assertIsNone(extract_stage_from_labels(["enhancement"]))

    def test_cli_json_and_event_path(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as tmp:
            event_path = Path(tmp) / "event.json"
            event_path.write_text(
                json.dumps(
                    {
                        "issue": {
                            "number": 2593,
                            "title": "Stage-gate workflow",
                            "body": "- [ ] Implement approval panel",
                            "labels": [{"name": "stage:implementation"}],
                        }
                    }
                ),
                encoding="utf-8",
            )
            proc = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    "scripts/validate_stage_gate_transition.py",
                    "--event-path",
                    str(event_path),
                    "--json",
                ],
                cwd=repo_root,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            payload = json.loads(proc.stdout)
            self.assertTrue(payload["valid"])
            self.assertEqual(payload["current_stage"], "design")
            self.assertEqual(payload["target_stage"], "implementation")


if __name__ == "__main__":
    unittest.main()
