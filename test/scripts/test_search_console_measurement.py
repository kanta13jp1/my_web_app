import importlib.util
import io
import json
from pathlib import Path
import unittest
from urllib.error import HTTPError

PATH = Path(__file__).resolve().parents[2] / 'scripts/search_console_measurement.py'
if not PATH.exists():
    PATH = Path(__file__).with_name('search_console_measurement.py')
spec = importlib.util.spec_from_file_location('gsc', PATH)
gsc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gsc)


class SearchConsoleMeasurementTest(unittest.TestCase):
    def test_request_final_data_and_exact_page_filter(self):
        body = gsc.request_body('2026-09-13', '2026-09-26', 'https://example.com/')
        self.assertEqual(body['dimensions'], ['date'])
        self.assertEqual(body['dataState'], 'final')
        self.assertEqual(body['dimensionFilterGroups'][0]['filters'][0]['operator'], 'equals')
        self.assertEqual(body['rowLimit'], 25000)
        with self.assertRaises(ValueError):
            gsc.request_body('2026-09-26', '2026-09-13')
        with self.assertRaises(ValueError):
            gsc.request_body('2024-01-01', '2026-09-13')

    def test_missing_days_not_zero_and_timezone_retained(self):
        raw = {'rows': [{'keys': ['2026-09-13'], 'clicks': 2.0, 'impressions': 10.0}]}
        snapshot = gsc.normalize(raw, 'https://example.com/', '2026-09-13', '2026-09-14')
        self.assertEqual(snapshot['missing_days'], ['2026-09-14'])
        self.assertEqual(snapshot['timezone'], 'America/Los_Angeles')
        self.assertEqual(snapshot['rows'][0]['click_rate'], .2)
        result = gsc.compare(snapshot, '2026-09-13', '2026-09-14', 1)
        self.assertEqual(result['status'], 'incomplete')
        self.assertIsNone(result['ratios']['impressions'])

    def test_invalid_rows_and_partial_responses(self):
        good = {'keys': ['2026-09-13'], 'clicks': 1, 'impressions': 2}
        for row in [{**good, 'clicks': -1}, {**good, 'impressions': '2'},
                    {**good, 'clicks': True}, {**good, 'clicks': 3},
                    {**good, 'impressions': float('nan')},
                    {**good, 'keys': ['2026-09-13', 'https://example.com/']}]:
            with self.subTest(row=row), self.assertRaises(ValueError):
                gsc.normalize({'rows': [row]}, 'x', '2026-09-13', '2026-09-14')
        for payload in ({'rows': [good, good]}, {'error': {'message': 'denied'}},
                        {'metadata': {'first_incomplete_date': '2026-09-13'}}):
            with self.assertRaises(ValueError):
                gsc.normalize(payload, 'x', '2026-09-13', '2026-09-14')

    def test_zero_denominator_not_infinite_growth(self):
        raw = {'rows': [
            {'keys': ['2026-09-13'], 'clicks': 0, 'impressions': 0},
            {'keys': ['2026-09-14'], 'clicks': 1, 'impressions': 2}]}
        result = gsc.compare(gsc.normalize(raw, 'x', '2026-09-13', '2026-09-14'),
                             '2026-09-13', '2026-09-14', 1)
        self.assertIsNone(result['ratios']['clicks'])
        self.assertIsNone(result['causal_effect'])

    def test_fixed_google_endpoint_and_redacted_error(self):
        captured = []
        class FakeOpener:
            def open(self, request, timeout):
                captured.append((request, timeout))
                return io.BytesIO(b'{"rows":[]}')
        gsc.fetch_snapshot('https://example.com/', {}, 'secret-for-test', FakeOpener())
        request, timeout = captured[0]
        self.assertEqual(request.full_url, 'https://www.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com%2F/searchAnalytics/query')
        self.assertEqual(timeout, 30)
        self.assertEqual(request.get_header('Authorization'), 'Bearer secret-for-test')
        class Denied:
            def open(self, request, timeout):
                raise HTTPError(request.full_url, 403, 'secret-for-test', {}, None)
        with self.assertRaises(RuntimeError) as error:
            gsc.fetch_snapshot('https://example.com/', {}, 'secret-for-test', Denied())
        self.assertNotIn('secret-for-test', str(error.exception))
        self.assertIsNone(gsc.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.example'))


if __name__ == '__main__':
    unittest.main()
