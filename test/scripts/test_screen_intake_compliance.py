import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import screen_intake_compliance as sic  # noqa: E402


class ScreenIntakeComplianceTest(unittest.TestCase):
    def test_benign_text_passes_cleanly_without_verification(self) -> None:
        res = sic.classify_intake_text(
            "UI Button Contrast Enhancement",
            "Improve dark-mode spacing and typography readability across notes list.",
            intake_source="notebooklm",
        )
        self.assertEqual(res.intake_source, "notebooklm")
        self.assertEqual(res.risk_category, "none")
        self.assertEqual(res.risk_score, 0)
        self.assertEqual(res.matched_keywords, [])
        self.assertFalse(res.requires_verification)
        self.assertEqual(res.review_status, "verified_safe")

    def test_antitrust_and_competition_law_keywords_flag_verification(self) -> None:
        antitrust = sic.classify_intake_text(
            "Antitrust review memo",
            "独占禁止法およびカルテルリスクに関する調査ノート",
            intake_source="notebooklm",
        )
        self.assertEqual(antitrust.risk_category, "antitrust")
        self.assertGreaterEqual(antitrust.risk_score, 40)
        self.assertIn("独占禁止法", antitrust.matched_keywords)
        self.assertIn("antitrust", antitrust.matched_keywords)
        self.assertTrue(antitrust.requires_verification)
        self.assertEqual(antitrust.review_status, "pending")

        comp = sic.classify_intake_text(
            "APAC M&A brief",
            "オーストラリア競争消費者法改正および企業結合規制への対応メモ",
            intake_source="notebooklm",
        )
        self.assertEqual(comp.risk_category, "competition_law")
        self.assertTrue(comp.requires_verification)
        self.assertIn("企業結合規制", comp.matched_keywords)
        self.assertIn("競争消費者法", comp.matched_keywords)

    def test_financial_regulatory_and_legal_compliance_categories(self) -> None:
        fin = sic.classify_intake_text(
            "Q4 財務予測レポート",
            "来期の売上予測と金商法上の開示留意点",
            intake_source="github_issue",
        )
        self.assertEqual(fin.risk_category, "financial_claim")
        self.assertTrue(fin.requires_verification)

        reg = sic.classify_intake_text(
            "GDPR と法規制対応",
            "個人情報保護法および輸出規制の確認事項",
        )
        self.assertEqual(reg.risk_category, "regulatory")
        self.assertTrue(reg.requires_verification)

        legal = sic.classify_intake_text(
            "法務リスク監査",
            "著作権侵害と訴訟リスクに関するレビュー",
        )
        self.assertEqual(legal.risk_category, "legal_compliance")
        self.assertTrue(legal.requires_verification)

    def test_cli_json_and_fail_on_risk_modes(self) -> None:
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = sic.main(
                [
                    "--title",
                    "企業結合規制レビュー",
                    "--content",
                    "Antitrust filing checklist",
                    "--source",
                    "notebooklm",
                    "--json",
                ]
            )
        self.assertEqual(rc, 0)
        parsed = json.loads(buf.getvalue())
        self.assertTrue(parsed["requires_verification"])
        self.assertEqual(parsed["intake_source"], "notebooklm")
        self.assertGreater(parsed["risk_score"], 0)

        with tempfile.TemporaryDirectory() as tmp:
            json_path = Path(tmp) / "intake.json"
            json_path.write_text(
                json.dumps(
                    {
                        "title": "法務リスク確認",
                        "content": "契約違反の検証が必要",
                        "intake_source": "manual",
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            buf2 = io.StringIO()
            with redirect_stdout(buf2):
                rc2 = sic.main(["--file", str(json_path), "--json", "--fail-on-risk"])
            self.assertEqual(rc2, 2)
            parsed2 = json.loads(buf2.getvalue())
            self.assertTrue(parsed2["requires_verification"])


if __name__ == "__main__":
    unittest.main()
