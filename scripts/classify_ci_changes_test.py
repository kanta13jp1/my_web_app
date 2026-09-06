#!/usr/bin/env python3
from __future__ import annotations

import unittest

from classify_ci_changes import classify


class ClassifyCiChangesTest(unittest.TestCase):
    def test_migration_does_not_start_flutter_deno_or_web(self) -> None:
        result = classify(["supabase/migrations/20260814000000_seed.sql"])

        self.assertTrue(result["migration"])
        self.assertFalse(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["edge"])
        self.assertFalse(result["caption"])
        self.assertTrue(result["deployable"])

    def test_seed_test_needs_flutter_but_not_web_build(self) -> None:
        result = classify(["test/services/ai_university_video_seed_test.dart"])

        self.assertTrue(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["deployable"])

    def test_app_code_needs_flutter_and_web(self) -> None:
        result = classify(["lib/pages/ai_university_page.dart"])

        self.assertTrue(result["flutter"])
        self.assertTrue(result["web"])

    def test_hosting_config_needs_web_deploy(self) -> None:
        result = classify(["firebase.json"])

        self.assertTrue(result["flutter"])
        self.assertTrue(result["web"])
        self.assertTrue(result["deployable"])

    def test_edge_and_caption_are_independent(self) -> None:
        edge = classify(["supabase/functions/app-hub/index.ts"])
        caption = classify(["services/caption-transcoder/test.js"])

        self.assertTrue(edge["edge"])
        self.assertFalse(edge["caption"])
        self.assertTrue(caption["caption"])
        self.assertFalse(caption["edge"])

    def test_tiger_status_triggers_tiger_group_only(self) -> None:
        result = classify(["assets/data/tiger_remediation_status.json"])

        self.assertTrue(result["tiger"])
        self.assertFalse(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["deployable"])

    def test_force_all_enables_every_group(self) -> None:
        self.assertTrue(all(classify([], force_all=True).values()))


if __name__ == "__main__":
    unittest.main()
