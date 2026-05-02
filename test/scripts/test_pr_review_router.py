#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from pr_review_router import ReviewItem, classify_item, render_markdown, route_items


class PrReviewRouterTest(unittest.TestCase):
    def test_routes_located_concrete_feedback_to_local_patch(self) -> None:
        category, reason = classify_item(
            ReviewItem(
                kind="review_comment",
                body="This null check is missing; please fix the error path.",
                path="lib/pages/foo.dart",
                line=42,
            )
        )

        self.assertEqual(category, "local_patch")
        self.assertIn("concrete", reason.lower())

    def test_routes_architecture_feedback_to_claude(self) -> None:
        category, _ = classify_item(
            ReviewItem(
                kind="pull_request_review",
                body="This changes the security model and needs an architecture decision.",
                state="CHANGES_REQUESTED",
            )
        )

        self.assertEqual(category, "needs_claude_code")

    def test_routes_product_feedback_to_user_judgment(self) -> None:
        category, _ = classify_item(
            ReviewItem(
                kind="review_comment",
                body="Please confirm the product behavior with the user before merging.",
                path="lib/pages/settings.dart",
            )
        )

        self.assertEqual(category, "needs_user_product_judgment")

    def test_routes_resolved_thread_to_stale(self) -> None:
        category, _ = classify_item(
            ReviewItem(kind="review_thread_comment", body="Please change this.", resolved=True)
        )

        self.assertEqual(category, "stale_superseded")

    def test_report_includes_boundaries_and_patch_paths(self) -> None:
        routed = route_items(
            [
                ReviewItem(
                    kind="review_comment",
                    body="Rename this unused import.",
                    path="lib/foo.dart",
                    line=7,
                    author="reviewer",
                )
            ]
        )
        report = render_markdown("owner/repo", 12, routed, "local test")

        self.assertIn("lib/foo.dart", report)
        self.assertIn("#1557", report)
        self.assertIn("local_patch", report)


if __name__ == "__main__":
    unittest.main()
