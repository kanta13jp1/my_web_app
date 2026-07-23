#!/usr/bin/env python3
"""Tests for the approval-gated first-user X candidate."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/first_user_x_candidate.py"
SPEC = importlib.util.spec_from_file_location("first_user_x_candidate", SCRIPT)
assert SPEC and SPEC.loader
first_user_x_candidate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(first_user_x_candidate)


class FirstUserXCandidateTest(unittest.TestCase):
    def build(self, dry_run: bool = True) -> dict[str, object]:
        return first_user_x_candidate.build_candidate_request(
            dry_run=dry_run,
            actor="tester",
            run_id="123",
            run_attempt="1",
            ref="refs/heads/main",
            sha="abc123",
        )

    def test_candidate_is_review_only_and_stable(self) -> None:
        payload = self.build()

        self.assertEqual(payload["action"], "x.candidate.create")
        self.assertEqual(
            payload["candidateKey"],
            "first-user-launch/outcome-first-a/v1",
        )
        self.assertEqual(payload["candidateType"], "first_user_launch")
        self.assertEqual(
            payload["sourceKind"],
            "x-first-user-launch-candidate.yml",
        )
        self.assertIs(payload["dryRun"], True)
        first_user_x_candidate.validate_candidate_request(payload)

    def test_parent_has_image_but_no_link(self) -> None:
        post = self.build()["postPayload"]

        self.assertEqual(post["action"], "x.post")
        self.assertNotIn("http://", post["text"])
        self.assertNotIn("https://", post["text"])
        self.assertLessEqual(len(post["text"]), 280)
        self.assertEqual(post["mediaType"], "image/png")
        self.assertTrue(post["mediaUrl"].endswith(".png"))
        self.assertTrue(post["mediaAlt"])
        self.assertIs(post["linkInReply"], True)

    def test_reply_contains_trial_and_campaign_attribution(self) -> None:
        post = self.build()["postPayload"]
        reply = post["replyTexts"][0]
        url = next(part for part in reply.split() if part.startswith("https://"))
        query = parse_qs(urlparse(url).query)

        self.assertEqual(query["lp_intent"], ["trial"])
        self.assertEqual(query["utm_source"], ["x"])
        self.assertEqual(query["utm_medium"], ["organic"])
        self.assertEqual(query["utm_campaign"], ["first_user_growth"])
        self.assertEqual(query["utm_content"], ["outcome_first_a"])

    def test_store_mode_only_changes_dry_run(self) -> None:
        preview = self.build(dry_run=True)
        stored = self.build(dry_run=False)

        self.assertIs(preview["dryRun"], True)
        self.assertIs(stored["dryRun"], False)
        preview["dryRun"] = False
        self.assertEqual(preview, stored)

    def test_cli_writes_valid_utf8_json(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "candidate.json"
            subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--dry-run",
                    "false",
                    "--actor",
                    "workflow-user",
                    "--output",
                    str(output),
                ],
                check=True,
                cwd=ROOT,
            )
            payload = json.loads(output.read_text(encoding="utf-8"))

        self.assertIs(payload["dryRun"], False)
        self.assertEqual(payload["context"]["actor"], "workflow-user")
        first_user_x_candidate.validate_candidate_request(payload)


if __name__ == "__main__":
    unittest.main()
