import json
import unittest

import dining_page_stub as fixture


class SyntheticBackendTest(unittest.TestCase):
    def setUp(self):
        for key in fixture.COUNTS:
            fixture.COUNTS[key] = 0

    def login(self, email):
        status, value = fixture.dispatch(
            'POST', '/auth/v1/token?grant_type=password', {},
            json.dumps({'email': email, 'password': fixture.PASSWORD}).encode(),
        )
        self.assertEqual(status, 200)
        return value['user']['id'], {'authorization': 'Bearer ' + value['access_token']}

    def test_owner_a_sees_only_fixture_and_b_sees_no_flow(self):
        a, headers_a = self.login('fixture-a@example.invalid')
        b, headers_b = self.login('fixture-b@example.invalid')
        status, rows = fixture.dispatch('GET', '/rest/v1/wealth_struggles?user_id=eq.' + a, headers_a)
        self.assertEqual((status, len(rows)), (200, 1))
        self.assertEqual(rows[0]['description'], '吉野家 食事')
        self.assertEqual(fixture.dispatch('GET', '/rest/v1/wealth_struggles?user_id=eq.' + b, headers_b), (200, []))
        self.assertEqual(fixture.dispatch('GET', '/rest/v1/asset_calendar_reflections?user_id=eq.' + a, headers_a), (200, []))
        self.assertEqual(fixture.dispatch('GET', '/rest/v1/asset_calendar_reflections?user_id=eq.' + b, headers_b), (200, []))
        self.assertEqual((fixture.COUNTS['flows_a'], fixture.COUNTS['flows_b']), (1, 1))
        self.assertEqual((fixture.COUNTS['reflection_a'], fixture.COUNTS['reflection_b']), (1, 1))

    def test_anonymous_and_cross_owner_reads_fail(self):
        a, _ = self.login('fixture-a@example.invalid')
        _, headers_b = self.login('fixture-b@example.invalid')
        target = '/rest/v1/wealth_struggles?user_id=eq.' + a
        self.assertEqual(fixture.dispatch('GET', target, {})[0], 403)
        self.assertEqual(fixture.dispatch('GET', target, headers_b)[0], 403)
        self.assertEqual(fixture.COUNTS['rejected_identity'], 2)

    def test_mutations_and_bad_identity_are_denied(self):
        a, headers = self.login('fixture-a@example.invalid')
        target = '/rest/v1/wealth_struggles?user_id=eq.' + a
        for method in ['POST', 'PATCH', 'PUT', 'DELETE', 'TRACE']:
            self.assertEqual(fixture.dispatch(method, target, headers)[0], 403)
        self.assertEqual(fixture.COUNTS['rejected_writes'], 5)
        self.assertEqual(fixture.dispatch('POST', '/auth/v1/token?grant_type=password', {}, b'[]')[0], 403)
        self.assertEqual(fixture.dispatch('GET', '/rest/v1/other', headers)[0], 404)

    def test_oversized_mutation_is_counted_before_body_read(self):
        handler = object.__new__(fixture.Handler)
        handler.headers = {'content-length': '1025'}
        handler.command = 'POST'
        errors = []
        handler.send_error = errors.append
        handler._handle()
        self.assertEqual(errors, [413])
        self.assertEqual(fixture.COUNTS['rejected_writes'], 1)
        self.assertTrue(callable(handler.do_TRACE))

    def test_invalid_length_and_transfer_encoding_are_counted(self):
        for headers in [
            {'content-length': '-1'},
            {'content-length': 'not-a-number'},
            {'content-length': '9' * 5000},
            {'content-length': '0', 'transfer-encoding': 'chunked'},
        ]:
            handler = object.__new__(fixture.Handler)
            handler.headers = headers
            handler.command = 'PATCH'
            errors = []
            handler.send_error = errors.append
            handler._handle()
            self.assertEqual(errors, [400])
        self.assertEqual(fixture.COUNTS['rejected_writes'], 4)


if __name__ == '__main__':
    unittest.main()
