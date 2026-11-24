"""Boundary and statistical checks with independent enumerated expectations."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'scripts' / 'seo_measurement_audit.py'
if not MODULE.exists():
    MODULE = Path(__file__).with_name('seo_measurement_audit.py')
spec = importlib.util.spec_from_file_location('audit', MODULE)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class MeasurementAuditTest(unittest.TestCase):
    def test_invalid_counts(self):
        for value in (-1, '2', 'hello', 1.5, None, True, False, float('nan'), float('inf'), [], {}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                audit.count(value)
        self.assertEqual(audit.count(0), 0)
        self.assertEqual(audit.count(10**30), 10**30)

    def test_dates_missing_duplicate_and_receipt_mismatch(self):
        row = dict(day='2026-09-13', daily_row_present=True, landing=1,
                   public_memo=0, signup_submit=0, receipt_landing=1,
                   receipt_public_memo=0, receipt_signup_submit=0)
        with self.assertRaises(ValueError):
            audit.daily_rows([row, row])
        with self.assertRaises(ValueError):
            audit.daily_rows([{**row, 'receipt_landing': 2}])
        with self.assertRaises(ValueError):
            audit.daily_rows([{**row, 'day': '2026-02-30'}])
        result = audit.week([row], '2026-09-13', 'landing')
        self.assertIsNone(result['total'])
        self.assertEqual(len(result['missing']), 6)
        absent = {**row, 'daily_row_present': False}
        self.assertEqual(len(audit.week([absent], '2026-09-13', 'landing')['missing']), 7)

    def test_timezone_midnight_and_dst(self):
        self.assertEqual(audit.local_day('2026-09-13T14:59:59+00:00', 'Asia/Tokyo'), '2026-09-13')
        self.assertEqual(audit.local_day('2026-09-13T15:00:00+00:00', 'Asia/Tokyo'), '2026-09-14')
        for timestamp in ('2026-11-01T01:30:00-04:00', '2026-11-01T01:30:00-05:00'):
            self.assertEqual(audit.local_day(timestamp, 'America/New_York'), '2026-11-01')
        with self.assertRaises(ValueError):
            audit.local_day('2026-11-01T01:30:00', 'America/New_York')

    def test_sign_probability_by_enumerating_all_signs(self):
        for n in range(1, 8):
            outcomes = list(product((-1, 1), repeat=n))
            for positive in range(n+1):
                distance = abs(2*positive-n)
                expected = sum(abs(sum(signs)) >= distance for signs in outcomes) / len(outcomes)
                after = [2]*positive + [0]*(n-positive)
                self.assertAlmostEqual(audit.sign_test([1]*n, after)['two_sided_p'], expected)
        self.assertEqual(audit.sign_test([1, 1], [1, 1])['two_sided_p'], 1)


if __name__ == '__main__':
    unittest.main()
