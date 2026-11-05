import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from audit_kokumin_candidate_dates import classify_date_tail


class CandidateDateEvidenceTest(unittest.TestCase):
    def test_parenthesized_dates_are_term_expiry_in_both_scripts(self):
        for value in ["(2027/04/29)", "（2027/05/01）"]:
            with self.subTest(value=value):
                result = classify_date_tail(value)
                self.assertEqual(result["dateEvidence"][0]["kind"], "term_expiry")
                self.assertIsNone(result["verifiedVoteDate"])
                self.assertFalse(result["eligibleForScheduleJoin"])

    def test_announcement_and_voting_columns_remain_distinct(self):
        result = classify_date_tail("2026/12/20 2026/12/27")
        self.assertEqual(result["dateEvidence"], [
            {"value": "2026-12-20", "kind": "reported_announcement_date"},
            {"value": "2026-12-27", "kind": "reported_voting_date"},
        ])
        self.assertIsNone(result["verifiedVoteDate"])

    def test_april_2027_plain_dates_are_not_confirmed(self):
        result = classify_date_tail("2027/04/02 2027/04/11")
        self.assertIsNone(result["verifiedVoteDate"])
        self.assertFalse(result["eligibleForScheduleJoin"])

    def test_lone_plain_date_does_not_guess_the_pdf_column(self):
        result = classify_date_tail("2026/12/20")
        self.assertEqual(result["dateEvidence"][0]["kind"], "unclassified_reported_date")

    def test_no_dates_produces_no_election_association(self):
        result = classify_date_tail("")
        self.assertEqual(result["dateEvidence"], [])
        self.assertFalse(result["eligibleForScheduleJoin"])

    def test_announcement_followed_by_term_expiry_is_not_a_vote_date(self):
        result = classify_date_tail("2027/04/02 (2027/04/29)")
        self.assertEqual(result["dateEvidence"][1]["kind"], "term_expiry")
        self.assertIsNone(result["verifiedVoteDate"])

    def test_invalid_dates_or_ambiguous_columns_fail_closed(self):
        for value in ["2026/02/29", "(2027/04/31)", "(2027/04/29",
                      "2027/04/29)", "（2027/04/29)", "2026/12/27予定",
                      "2026/12/20 2026/12/27 2027/01/20",
                      "(2027/04/29) 2027/05/01"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                classify_date_tail(value)


if __name__ == "__main__":
    unittest.main()
