import unittest
from documentation_quality_gate import new_findings


class DeltaTest(unittest.TestCase):
    def test_old_findings_remain_reported_but_are_not_new(self):
        old = [{'file': 'a.md', 'detail': 'teh ==> the'}]
        self.assertEqual(new_findings(old, old), [])

    def test_new_or_duplicate_occurrences_block(self):
        old = [{'file': 'a.md', 'detail': 'teh ==> the'}]
        self.assertEqual(len(new_findings(old * 2, old)), 1)
        self.assertEqual(len(new_findings([{'file': 'b.md', 'detail': 'teh ==> the'}], old)), 1)

    def test_fixed_findings_do_not_block(self):
        self.assertEqual(new_findings([], [{'reason': 'missing_local_target'}]), [])


if __name__ == '__main__':
    unittest.main()
