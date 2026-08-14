import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = (
    Path(__file__).resolve().parents[2]
    / "scripts"
    / "update_kokumin_local_endorsements.py"
)
SPEC = importlib.util.spec_from_file_location("endorsement_updater", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class KokuminLocalEndorsementUpdaterTest(unittest.TestCase):
    def test_parses_endorsements_recommendations_and_career_breakdown(self):
        page = """
2026/08/05現在
 1 北海道 札幌市議会議員選挙 7 候補 A 男 38 新 有 公認 (2027/05/01)
 2 北海道 札幌市議会議員選挙 7 候補 B 女 48 現 3 有 公認 (2027/05/01)
 3 東京都 区議会議員選挙 30 候補 C 男 60 元 1 有 推薦 (2027/05/01)
"""
        rows = updater.parse_candidate_rows([page])

        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0]["prefecture"], "北海道")
        self.assertEqual(rows[1]["career"], "incumbent")
        self.assertEqual(rows[2]["prefecture"], "東京")
        self.assertEqual(rows[2]["decision"], "recommendation")
        self.assertEqual(updater.parse_source_as_of([page]), "2026-08-05")

    def test_rejects_large_drop_from_previous_snapshot(self):
        current = {
            "officialEndorsements": {
                "totalCount": 60,
                "incumbentCount": 20,
                "newcomerCount": 30,
                "formerCount": 10,
                "prefectureCount": 10,
            },
            "prefectures": [
                {
                    "prefecture": f"P{index}",
                    "totalCount": 6,
                    "incumbentCount": 2,
                    "newcomerCount": 3,
                    "formerCount": 1,
                }
                for index in range(10)
            ],
        }
        previous = {"officialEndorsements": {"totalCount": 100}}

        with self.assertRaisesRegex(ValueError, "fell from 100 to 60"):
            updater.validate_snapshot(current, previous=previous)

    def test_renders_dart_fallback_from_the_canonical_snapshot(self):
        snapshot = {
            "sourceUrl": "https://new-kokumin.jp/local-election-list",
            "sourceAsOf": "2026-08-10",
            "sourceDocumentSha256": "abc123",
            "officialEndorsements": {
                "totalCount": 1,
                "incumbentCount": 0,
                "newcomerCount": 1,
                "formerCount": 0,
                "prefectureCount": 1,
            },
            "recommendations": {"totalCount": 9},
            "prefectures": [
                {
                    "prefecture": "佐賀",
                    "totalCount": 1,
                    "incumbentCount": 0,
                    "newcomerCount": 1,
                    "formerCount": 0,
                }
            ],
        }

        rendered = updater.render_dart_fallback(snapshot)

        self.assertIn(
            "const String dpjOfficialEndorsementSourceUrl =\n"
            "    'https://new-kokumin.jp/local-election-list';",
            rendered,
        )
        self.assertIn(
            "const String dpjOfficialEndorsementSourceDocumentSha256 =\n"
            "    'abc123';",
            rendered,
        )
        self.assertIn("dpjOfficialEndorsementSourceAsOf = '2026-08-10'", rendered)
        self.assertIn("prefecture: '佐賀'", rendered)
        self.assertIn("const int dpjOfficialEndorsementTotal = 1;", rendered)
        self.assertIn("RegExp(r'[都府県]$')", rendered)


if __name__ == "__main__":
    unittest.main()
