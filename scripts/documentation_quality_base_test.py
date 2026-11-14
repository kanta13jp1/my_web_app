import unittest
from documentation_quality_base import comparison_base


class ComparisonBaseTest(unittest.TestCase):
    def test_stale_payload_uses_actual_merge_parent(self):
        self.assertEqual(comparison_base('a' * 40, ['b' * 40, 'c' * 40]), 'b' * 40)

    def test_matching_payload_is_unchanged(self):
        self.assertEqual(comparison_base('a' * 40, ['a' * 40, 'c' * 40]), 'a' * 40)

    def test_non_merge_or_shallow_checkout_fails_closed(self):
        for parents in ([], ['b' * 40], ['b' * 40] * 3):
            with self.subTest(parents=parents), self.assertRaises(ValueError):
                comparison_base('a' * 40, parents)

    def test_invalid_shas_fail_closed(self):
        for event, parents in [('main', ['b' * 40, 'c' * 40]), ('a' * 40, ['HEAD', 'c' * 40])]:
            with self.subTest(event=event), self.assertRaises(ValueError):
                comparison_base(event, parents)


if __name__ == '__main__':
    unittest.main()
