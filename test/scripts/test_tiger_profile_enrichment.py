import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "tiger_profile_enrichment.py"
SPEC = importlib.util.spec_from_file_location("tiger_profile_enrichment", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def personas():
    return {
        "snapshot_date": "2026-08-23",
        "domain_labels_ja": {"education": "教育・スクール"},
        "question_text_ja": {
            "market_demand": "実在する顧客は誰か。",
            "revenue_model": "誰が何に支払うのか。",
        },
        "people": [
            {
                "seat": 1,
                "name": "一次情報が強い虎",
                "roster_status": "current",
                "career": {
                    "company_role": "株式会社例 代表",
                    "business_domains": ["education"],
                },
                "public_viewpoint": {
                    "summary": "一次情報で審査姿勢を確認済み。",
                    "style_tags": ["numbers_first"],
                },
                "programme_behavior": {"appearances": 10, "investment_count": 4},
                "reviewer_model": {
                    "business_viability_weight_percent": {
                        "market_demand": 60,
                        "revenue_model": 40,
                    },
                    "primary_question_dimensions": ["market_demand", "revenue_model"],
                },
                "confidence": {
                    "career": 5,
                    "viewpoint": 5,
                    "programme_behavior": 5,
                    "overall": 5,
                },
                "evidence_source_ids": ["S001"],
            },
            {
                "seat": 2,
                "name": "追加調査が必要な虎",
                "roster_status": "historical",
                "career": {
                    "company_role": "公開情報未確認",
                    "business_domains": ["education"],
                },
                "public_viewpoint": {"summary": "限定的なモデル。", "style_tags": []},
                "programme_behavior": {"appearances": 1, "investment_count": 0},
                "reviewer_model": {
                    "business_viability_weight_percent": {"market_demand": 100},
                    "primary_question_dimensions": ["market_demand"],
                },
                "confidence": {
                    "career": 1,
                    "viewpoint": 1,
                    "programme_behavior": 1,
                    "overall": 1,
                },
                "evidence_source_ids": ["S002"],
            },
        ],
    }


def catalog():
    return {
        "schema_version": 1,
        "snapshot_date": "2026-08-23",
        "profiles": [
            {
                "seat": 1,
                "name": "一次情報が強い虎",
                "company_role": "株式会社例 代表",
                "business_summary": "教育事業",
                "profile_url": "https://example.com/1",
                "birth_date": None,
                "birth_date_source_url": None,
            },
            {
                "seat": 2,
                "name": "追加調査が必要な虎",
                "company_role": "公開情報未確認",
                "business_summary": "公開情報未確認",
                "profile_url": "https://example.com/2",
                "birth_date": None,
                "birth_date_source_url": None,
            },
        ],
    }


class TigerProfileEnrichmentTests(unittest.TestCase):
    def test_strong_evidence_has_full_review_reflection_without_guessing_age(self):
        result = MODULE.build_catalog(personas(), catalog(), batch_size=1, round_number=1)
        profile = result["profiles"][0]

        self.assertEqual(result["schema_version"], 2)
        self.assertEqual(profile["review_reflection_percent"], 100)
        self.assertEqual(profile["review_reflection_mode"], "profile_guided")
        self.assertLess(profile["profile_completeness_percent"], 100)
        self.assertIn("生年月日の一次公開情報", profile["next_research_targets"])
        self.assertEqual(profile["review_focus_dimensions"][0]["label"], "市場需要")

    def test_low_evidence_stays_neutral_and_is_selected_for_next_batch(self):
        result = MODULE.build_catalog(personas(), catalog(), batch_size=1, round_number=3)
        weak = result["profiles"][1]

        self.assertEqual(weak["review_reflection_percent"], 20)
        self.assertEqual(weak["review_reflection_mode"], "neutral_guarded")
        self.assertIn("中立スキャンを優先", weak["review_application_rule"])
        self.assertEqual(result["enrichment"]["round"], 3)
        self.assertEqual(result["enrichment"]["next_batch"][0]["seat"], 2)

    def test_seat_name_mismatch_fails_closed(self):
        bad = catalog()
        bad["profiles"][0]["name"] = "別人"
        with self.assertRaisesRegex(ValueError, "name mismatch"):
            MODULE.build_catalog(personas(), bad)


if __name__ == "__main__":
    unittest.main()
