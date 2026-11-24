import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from tag_wps_diversity_knowledge import (  # noqa: E402
    MOFA_NAP3_REF,
    MOFA_WPS_NAP3_URL,
    UNSCR_1325_REF,
    UNSCR_1325_URL,
    main,
    sanitize_reference_url,
    tag_wps_diversity_text,
)


class TagWpsDiversityKnowledgeTest(unittest.TestCase):
    def test_tags_wps_and_mofa_action_plan_with_verified_references(self) -> None:
        result = tag_wps_diversity_text(
            title="第3次WPS行動計画の社内適用ノート",
            content=(
                "国連安保理決議1325号（UNSCR 1325）および女性・平和・安全保障に基づき、"
                "意思決定における女性の参画とジェンダー平等を推進する。"
            ),
        )
        self.assertEqual(result.primary_topic, "wps")
        self.assertIn("WPS", result.tags)
        self.assertIn("ジェンダー", result.tags)
        self.assertIn("人権・行動計画", result.tags)
        self.assertIn(UNSCR_1325_REF, result.framework_references)
        self.assertIn(MOFA_NAP3_REF, result.framework_references)
        self.assertEqual(result.reference_url, MOFA_WPS_NAP3_URL)
        self.assertTrue(result.requires_admin_review)
        self.assertEqual(result.suggested_review_status, "pending_review")
        self.assertGreater(result.confidence_score, 0)

    def test_tags_diversity_and_gender_inclusion_without_wps_reference(self) -> None:
        result = tag_wps_diversity_text(
            title="DE&I 採用ガイドライン改定案",
            content="組織のダイバーシティとインクルージョン、男女共同参画を推進する。",
        )
        self.assertIn("ダイバーシティ", result.tags)
        self.assertIn("ジェンダー", result.tags)
        self.assertNotIn("WPS", result.tags)
        self.assertTrue(result.requires_admin_review)
        self.assertEqual(result.reference_url, "")

    def test_benign_text_returns_general_with_zero_confidence(self) -> None:
        result = tag_wps_diversity_text(
            title="Markdown ショートカット一覧",
            content="キーボード操作のメモを整理しました。",
        )
        self.assertEqual(result.primary_topic, "general")
        self.assertEqual(result.tags, [])
        self.assertEqual(result.confidence_score, 0)
        self.assertFalse(result.requires_admin_review)

    def test_rejects_unsafe_url_and_runs_cli_json_mode(self) -> None:
        with self.assertRaises(ValueError):
            sanitize_reference_url("javascript:alert(1)")

        self.assertEqual(sanitize_reference_url(UNSCR_1325_URL), UNSCR_1325_URL)

        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = main([
                "--title",
                "UNSCR 1325 briefing",
                "--content",
                "Women, peace and security humanitarian response",
                "--json",
                "--fail-on-review-needed",
            ])
        self.assertEqual(rc, 2)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["primary_topic"], "wps")
        self.assertEqual(payload["reference_url"], UNSCR_1325_URL)
        self.assertTrue(payload["requires_admin_review"])

        buf_clean = io.StringIO()
        with redirect_stdout(buf_clean):
            rc_clean = main([
                "--title",
                "CI cache settings",
                "--content",
                "Cache flutter dependencies cleanly.",
                "--json",
                "--fail-on-review-needed",
            ])
        self.assertEqual(rc_clean, 0)


if __name__ == "__main__":
    unittest.main()
