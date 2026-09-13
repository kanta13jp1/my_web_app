import unittest
from ai_university_update_report import accounting, upsert


class ProviderReportTest(unittest.TestCase):
    def test_all_statuses_and_total(self):
        result = accounting([{"provider": p} for p in "abc"], "a\tsucceeded\nb\tfailed\nc\tskipped\n")
        self.assertEqual([result[k] for k in ("total", "succeeded", "failed", "skipped")], [3, 1, 1, 1])

    def test_reject_incomplete_duplicate_unknown_and_bad_status(self):
        for journal in ("", "a\tsucceeded\na\tfailed", "b\tsucceeded", "a\tunknown"):
            with self.subTest(journal=journal), self.assertRaises(ValueError):
                accounting([{"provider": "a"}], journal)

    def test_retry_same_run_replaces_section(self):
        first = upsert("# Preserved\n", "1", "old")
        second = upsert(first, "1", "new")
        self.assertEqual(second.count("ai-university-run:1:start"), 1)
        self.assertNotIn("old", second)
        self.assertIn("# Preserved", second)
        self.assertEqual(upsert(second, "1", "new"), second)

    def test_different_runs_preserved(self):
        first = upsert("", "1", "first")
        self.assertIn("first", upsert(first, "2", "second"))

    def test_duplicate_keys_fail(self):
        block = upsert("", "1", "x")
        with self.assertRaises(ValueError):
            upsert(block + block, "2", "y")


if __name__ == "__main__":
    unittest.main()
