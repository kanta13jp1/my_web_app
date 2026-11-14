import json
import unittest
from unittest.mock import patch
import subprocess

import dining_page_stub as fixture


class SyntheticBackendTest(unittest.TestCase):
    def setUp(self):
        fixture.PHASE = 'unknown'
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

    def test_read_rpc_is_authenticated_and_telemetry_is_rejected(self):
        _, headers = self.login('fixture-a@example.invalid')
        rpc = '/rest/v1/rpc/asset_management_recent_cfo_assets'
        body = b'{"p_lookback_days":400}'
        self.assertEqual(fixture.dispatch('POST', rpc, headers, body), (200, []))
        self.assertEqual(fixture.dispatch('POST', rpc, {}, body)[0], 403)
        self.assertEqual(fixture.dispatch('POST', rpc, headers, b'{"p_lookback_days":true}')[0], 403)
        self.assertEqual(fixture.dispatch('POST', '/rest/v1/display_mode_events', headers, b'{}')[0], 403)
        self.assertEqual(fixture.dispatch('POST', '/rest/v1/cfo_assets', headers, b'{}')[0], 403)
        self.assertEqual((fixture.COUNTS['read_rpc_a'], fixture.COUNTS['read_rpc_b']), (1, 0))
        self.assertEqual(fixture.COUNTS['rejected_telemetry'], 1)
        self.assertEqual(fixture.COUNTS['rejected_authorized_telemetry'], 1)
        self.assertEqual(fixture.COUNTS['rejected_writes'], 2)
        self.assertEqual(fixture.dispatch('POST', '/rest/v1/display_mode_events', {}, b'{}')[0], 403)
        self.assertEqual(fixture.COUNTS['rejected_telemetry'], 2)
        self.assertEqual(fixture.COUNTS['rejected_authorized_telemetry'], 1)

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

    @patch('builtins.print')
    def test_rejection_diagnostic_uses_only_fixed_categories(self, output):
        fixture.report_rejection('POST', '/rest/v1/asset_pref_mirror?private=value', 'denied_mutation')
        event = json.loads(output.call_args.args[0].removeprefix('FIXTURE_REJECTED '))
        self.assertEqual(event, {'method': 'POST', 'route': 'asset_pref_mirror',
                                 'reason': 'denied_mutation', 'phase': 'unknown',
                                 'length_bucket': 'unknown'})
        fixture.report_rejection('SECRET_METHOD', '/private/secret?token=secret', 'invalid_length')
        message = output.call_args.args[0]
        self.assertNotIn('secret', message.lower())
        self.assertEqual(json.loads(message.removeprefix('FIXTURE_REJECTED ')),
                         {'method': 'OTHER', 'route': 'other', 'reason': 'invalid_length',
                          'phase': 'unknown', 'length_bucket': 'unknown'})

    @patch.object(fixture.subprocess, 'run')
    def test_namespace_guard_accepts_only_single_loopback(self, run):
        run.return_value.stdout = b'[{"ifname":"lo"}]'
        self.assertTrue(fixture.namespace_only_loopback())
        run.assert_called_once()
        for value in [b'[]', b'[{"ifname":"lo"},{"ifname":"eth0"}]',
                      b'[{"ifname":"eth0"}]', b'[{"name":"lo"}]',
                      b'{}', b'not json', b'[{"ifname":"lo"},{"ifname":"lo"}]']:
            run.return_value.stdout = value
            self.assertFalse(fixture.namespace_only_loopback(), value)
        for error in [OSError(), subprocess.TimeoutExpired('ip', 5),
                      subprocess.CalledProcessError(1, 'ip')]:
            run.side_effect = error
            self.assertFalse(fixture.namespace_only_loopback())


    def test_phase_rejects_missing_blank_duplicates_and_extra_keys(self):
        for phase in fixture.PHASES:
            self.assertEqual(fixture.dispatch('GET', '/__fixture_phase?phase=' + phase, {}),
                             (200, {'phase': phase}))
        for target in ('/__fixture_phase', '/__fixture_phase?phase=',
                       '/__fixture_phase?phase=page_a&phase=',
                       '/__fixture_phase?phase=page_a&token=',
                       '/__fixture_phase?phase=page_a&token=synthetic_secret',
                       '/__fixture_phase?phase=page_a&phase=page_b'):
            fixture.PHASE = 'page_a'
            response = fixture.dispatch('GET', target, {})
            self.assertEqual(response, (400, {'phase': 'unknown'}))
            self.assertEqual(fixture.PHASE, 'unknown')
            self.assertNotIn('synthetic_secret', str(response))
        with patch('builtins.print'):
            self.assertEqual(fixture.dispatch('POST', '/__fixture_phase?phase=page_a', {})[0], 403)

    @patch('builtins.print')
    def test_fixed_prefix_classification_never_prints_untrusted_input(self, output):
        pairs = {'/auth/v1/synthetic_secret?token=synthetic_secret': 'auth_other',
                 '/rest/v1/rpc/synthetic_secret?token=synthetic_secret': 'rest_rpc_other',
                 '/rest/v1/synthetic_secret?token=synthetic_secret': 'rest_table_other',
                 '/functions/v1/synthetic_secret?token=synthetic_secret': 'functions_other',
                 '/storage/v1/synthetic_secret?token=synthetic_secret': 'storage_other',
                 '/realtime/synthetic_secret?token=synthetic_secret': 'realtime_other',
                 '/private/synthetic_secret?token=synthetic_secret': 'other'}
        for target, expected in pairs.items():
            fixture.report_rejection('POST', target, 'oversize_body', 1025)
            message = output.call_args.args[0]
            self.assertNotIn('synthetic_secret', message)
            event = json.loads(message.removeprefix('FIXTURE_REJECTED '))
            self.assertEqual((event['route'], event['phase'], event['length_bucket']),
                             (expected, 'unknown', '1025_to_4096'))
        fixture.report_rejection('SECRET_METHOD', '/private/synthetic_secret',
                                 'synthetic_secret_reason', None)
        message = output.call_args.args[0]
        self.assertNotIn('secret', message.lower())
        event = json.loads(message.removeprefix('FIXTURE_REJECTED '))
        self.assertEqual((event['method'], event['reason']), ('OTHER', 'unknown'))

    def test_length_bucket_boundaries(self):
        for value, expected in ((None, 'unknown'), (-1, 'unknown'), (True, 'unknown'),
                                (1024, 'at_most_1024'), (1025, '1025_to_4096'),
                                (4096, '1025_to_4096'), (4097, '4097_to_16384'),
                                (16384, '4097_to_16384'), (16385, 'above_16384')):
            self.assertEqual(fixture.length_bucket(value), expected)

    @patch('builtins.print')
    def test_oversize_rejected_without_reading_or_logging_sensitive_data(self, output):
        class Unreadable:
            def read(self, *_):
                raise AssertionError('oversized body was read')
        handler = object.__new__(fixture.Handler)
        handler.headers = {'content-length': '1025', 'authorization': 'synthetic_secret'}
        handler.path = '/functions/v1/synthetic_secret?token=synthetic_secret'
        handler.command = 'POST'
        handler.rfile = Unreadable()
        errors = []
        handler.send_error = errors.append
        handler._handle()
        self.assertEqual(errors, [413])
        self.assertEqual(fixture.COUNTS['rejected_writes'], 1)
        message = output.call_args.args[0]
        self.assertNotIn('synthetic_secret', message)
        self.assertEqual(json.loads(message.removeprefix('FIXTURE_REJECTED '))['route'],
                         'functions_other')


if __name__ == '__main__':
    unittest.main()
