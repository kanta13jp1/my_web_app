import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


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

    def test_reads_decision_column_and_separates_mayoral_rows(self):
        text = """2026/11/4現在
1 北海道 札幌市議会議員選挙 7 公認 名前 女 35 新 有 推薦 (2027/5/1)
2 北海道 札幌市議会議員選挙 7 推薦 名前 男 44 現 1 有 公認 (2027/5/1)
1 東京都 架空市長選挙 1 候補 A 女 50 新 無 推薦 (2027/5/1)
2 東京都 架空町長選挙 1 候補 B 男 51 新 有 公認 (2027/5/1)"""
        with patch.object(updater, "MIN_OFFICIAL_ENDORSEMENTS", 1), patch.object(updater, "MIN_PREFECTURES", 1):
            snapshot = updater.build_snapshot(b"fixture", [text], "https://example.org/list")
        self.assertEqual(snapshot["candidateRowCount"], 4)
        self.assertEqual(snapshot["officialEndorsements"]["totalCount"], 1)
        self.assertEqual(snapshot["officialEndorsements"]["incumbentCount"], 1)
        self.assertEqual(snapshot["recommendations"], {"totalCount": 2, "mayoralCount": 1})
        self.assertEqual(snapshot["mayoralEndorsementCount"], 1)

    def test_rejects_unknown_elections_and_malformed_decisions(self):
        for name, decision in (
            ("衆議院議員選挙", "公認"), ("新形式選挙", "推薦"),
            ("架空市議会議員選挙", "未定"), ("架空市議会議員選挙", "公認予定"),
        ):
            with self.subTest(name=name, decision=decision), self.assertRaises(ValueError):
                updater.parse_candidate_rows([
                    f"1 北海道 {name} 7 候補 公認 男 35 新 有 {decision} (2027/5/1)"
                ])

    def test_rejects_extra_decisions_and_invalid_date_columns(self):
        row = "1 北海道 架空市議会議員選挙 7 公認 名前 男 35 新 有 "
        for tail in (
            "公認 推薦 (2027/5/1)", "推薦 公認 2027/4/25 2027/5/1",
            "公認 (2027/5/1) 推薦", "公認 (2027/2/30)", "公認",
        ):
            with self.subTest(tail=tail), self.assertRaises(ValueError):
                updater.parse_candidate_rows([row + tail])
        for tail in ("推薦 (2027/5/1)", "推薦 （2027/5/1）", "推薦 2027/4/25 2027/5/1"):
            with self.subTest(tail=tail):
                self.assertEqual(updater.parse_candidate_rows([row + tail])[0]["decision"], "recommendation")

    def test_source_date_accepts_one_or_two_digit_month_and_day(self):
        for source, expected in (
            ("2026/11/4現在", "2026-11-04"),
            ("2026/1/4現在", "2026-01-04"),
            ("2026/01/04現在", "2026-01-04"),
            ("2026/1/14現在", "2026-01-14"),
        ):
            with self.subTest(source=source):
                self.assertEqual(updater.parse_source_as_of([source]), expected)

    def test_source_date_rejects_invalid_calendar_dates(self):
        with self.assertRaises(ValueError):
            updater.parse_source_as_of(["2026/2/30現在"])

    def test_classifies_assembly_category_from_the_election_name(self):
        page = """
2026/08/05現在
 1 北海道 北海道議会議員選挙 50 候補 A 男 38 新 有 公認 (2027/05/01)
 2 東京都 東京都議会議員選挙 5 候補 B 女 48 現 3 有 公認 (2027/05/01)
 3 埼玉県 久喜市議会議員選挙 20 候補 C 男 40 新 有 公認 (2027/05/01)
 4 東京都 区議会議員選挙 30 候補 D 男 60 元 1 有 公認 (2027/05/01)
 5 東京都 知事選挙 1 候補 E 男 55 新 有 公認 (2027/05/01)
"""
        rows = updater.parse_candidate_rows([page])

        self.assertEqual(
            [row["assemblyCategory"] for row in rows],
            ["prefectural", "prefectural", "municipal", "municipal", "mayoral"],
        )

    def test_build_snapshot_aggregates_prefectural_and_municipal_counts(self):
        pdf_bytes = b"%PDF-1.4 test"
        page = """
2026/08/05現在
 1 北海道 北海道議会議員選挙 50 候補 A 男 38 新 有 公認 (2027/05/01)
 2 埼玉県 久喜市議会議員選挙 20 候補 B 男 40 新 有 公認 (2027/05/01)
 3 埼玉県 春日部市議会議員選挙 20 候補 C 女 45 現 2 有 公認 (2027/05/01)
"""
        original_min_endorsements = updater.MIN_OFFICIAL_ENDORSEMENTS
        original_min_prefectures = updater.MIN_PREFECTURES
        updater.MIN_OFFICIAL_ENDORSEMENTS = 1
        updater.MIN_PREFECTURES = 1
        try:
            snapshot = updater.build_snapshot(
                pdf_bytes, [page], "https://new-kokumin.jp/local-election-list"
            )
        finally:
            updater.MIN_OFFICIAL_ENDORSEMENTS = original_min_endorsements
            updater.MIN_PREFECTURES = original_min_prefectures

        summary = snapshot["officialEndorsements"]
        self.assertEqual(summary["prefecturalCount"], 1)
        self.assertEqual(summary["municipalCount"], 2)

        saitama = next(
            row for row in snapshot["prefectures"] if row["prefecture"] == "埼玉"
        )
        self.assertEqual(saitama["prefecturalCount"], 0)
        self.assertEqual(saitama["municipalCount"], 2)

    def test_rejects_assembly_breakdown_exceeding_the_prefecture_total(self):
        current = {
            "officialEndorsements": {
                "totalCount": 60,
                "incumbentCount": 20,
                "newcomerCount": 30,
                "formerCount": 10,
                "prefectureCount": 10,
                "prefecturalCount": 0,
                "municipalCount": 60,
            },
            "prefectures": [
                {
                    "prefecture": "P0",
                    "totalCount": 6,
                    "incumbentCount": 2,
                    "newcomerCount": 3,
                    "formerCount": 1,
                    "prefecturalCount": 4,
                    "municipalCount": 4,
                },
                *[
                    {
                        "prefecture": f"P{index}",
                        "totalCount": 6,
                        "incumbentCount": 2,
                        "newcomerCount": 3,
                        "formerCount": 1,
                        "prefecturalCount": 0,
                        "municipalCount": 0,
                    }
                    for index in range(1, 10)
                ],
            ],
        }

        with self.assertRaisesRegex(ValueError, "Assembly breakdown does not equal total for"):
            updater.validate_snapshot(current)

    def test_rejects_large_drop_from_previous_snapshot(self):
        current = {
            "officialEndorsements": {
                "totalCount": 60,
                "incumbentCount": 20,
                "newcomerCount": 30,
                "formerCount": 10,
                "prefectureCount": 10,
                "municipalCount": 60,
            },
            "prefectures": [
                {
                    "prefecture": f"P{index}",
                    "totalCount": 6,
                    "incumbentCount": 2,
                    "newcomerCount": 3,
                    "formerCount": 1,
                    "municipalCount": 6,
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
                "prefecturalCount": 0,
                "municipalCount": 1,
            },
            "recommendations": {"totalCount": 9},
            "prefectures": [
                {
                    "prefecture": "佐賀",
                    "totalCount": 1,
                    "incumbentCount": 0,
                    "newcomerCount": 1,
                    "formerCount": 0,
                    "prefecturalCount": 0,
                    "municipalCount": 1,
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
        self.assertIn("municipalCount: 1,", rendered)
        self.assertIn("const int dpjOfficialEndorsementTotal = 1;", rendered)
        self.assertIn(
            "const int dpjOfficialEndorsementPrefecturalTotal = 0;", rendered
        )
        self.assertIn(
            "const int dpjOfficialEndorsementMunicipalTotal = 1;", rendered
        )
        self.assertIn("RegExp(r'[都府県]$')", rendered)


if __name__ == "__main__":
    unittest.main()
