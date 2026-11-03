"""Pure checks only; never starts a fixture or opens a socket."""
import hashlib
import contextlib
import io
import json
from pathlib import Path
import queue
import subprocess
import unittest
import stack_runner as runner


class RunnerTests(unittest.TestCase):
    def test_fixed_inputs_match_reviewed_bytes(self):
        for name, expected in runner.FIXED.items():
            with self.subTest(name=name):
                self.assertEqual(hashlib.sha256((Path(__file__).parent / name).read_bytes()).hexdigest(), expected)

    def test_positive_rows_required_for_outage_snapshot(self):
        fixture = runner.Fixture.__new__(runner.Fixture)
        rows = {key: [{'id': 'a'}, {'id': 'b'}]
                for key in ('accounts', 'observations', 'selections', 'history')}
        fixture.db_sql = lambda _sql: '1\n' + json.dumps(rows)
        self.assertEqual(fixture.snapshot(), rows)
        rows['history'] = []
        with self.assertRaisesRegex(RuntimeError, 'positive rows'):
            fixture.snapshot()

    def test_egress_probe_must_report_blocked(self):
        fixture = runner.Fixture.__new__(runner.Fixture)
        fixture.client_python = lambda _code: 'NOT_BLOCKED'
        with self.assertRaisesRegex(RuntimeError, 'egress'):
            fixture.check_egress()
        fixture.client_python = lambda _code: 'BLOCKED\n'
        fixture.check_egress()

    def test_client_eof_fails_without_waiting_for_timeout(self):
        output = queue.Queue()
        output.put(None)
        class Exited:
            def poll(self): return 7
        with self.assertRaises(runner.OwnerClientExited) as error:
            runner.Fixture.wait_marker(Exited(), output, 'SYNTHETIC_INITIAL_READY', timeout=10)
        self.assertEqual(error.exception.exit_code, 7)

    def test_client_diagnostic_requires_allowlisted_category_and_status(self):
        class Exited:
            def poll(self): return 1
        output = queue.Queue()
        output.put('SYNTHETIC_CLIENT_ERROR:signup_failed:signup:422:validation_failed')
        with self.assertRaises(runner.OwnerClientFailure) as error:
            runner.Fixture.wait_marker(Exited(), output, 'SYNTHETIC_INITIAL_READY', timeout=2)
        self.assertEqual((error.exception.category, error.exception.status), ('signup_failed', 422))
        self.assertEqual((error.exception.operation, error.exception.response_code), ('signup', 'validation_failed'))
        output.put('SYNTHETIC_CLIENT_ERROR:arbitrary_secret:signup:422:validation_failed')
        output.put(None)
        with self.assertRaises(runner.OwnerClientExited) as error:
            runner.Fixture.wait_marker(Exited(), output, 'SYNTHETIC_INITIAL_READY', timeout=2)
        self.assertNotIn('arbitrary_secret', str(error.exception))

    def test_sql_failure_reports_only_sqlstate(self):
        fixture = runner.Fixture.__new__(runner.Fixture)
        fixture.db_id, fixture.token = 'synthetic-id', 'synthetic-token'
        fixture.check_db = lambda **_kwargs: None
        fixture.check_network = lambda: None
        def fail(*_args, **_kwargs):
            raise subprocess.CalledProcessError(1, 'synthetic', stderr='ERROR:  42723\nprivate synthetic detail')
        fixture.cmd = fail
        with self.assertRaises(runner.FixtureSqlError) as error:
            fixture.db_sql('synthetic')
        self.assertEqual(error.exception.sqlstate, '42723')
        self.assertNotIn('private synthetic detail', str(error.exception))

    def test_auth_log_diagnostic_returns_only_fixed_categories(self):
        raw = 'permission denied synthetic-email-and-token-secret'
        result = runner.classify_auth_log(raw)
        self.assertEqual(result, ['db_permission'])
        self.assertNotIn('synthetic-email-and-token-secret', str(result))
        self.assertEqual(runner.classify_auth_log('unrecognized private data'), [])

    def test_auth_metadata_diagnostic_outputs_only_allowlisted_state(self):
        fixture = runner.Fixture.__new__(runner.Fixture)
        fixture.check_component = lambda _name: 'synthetic-container'
        fixture.cmd = lambda *_args: subprocess.CompletedProcess([], 0, 'SQLSTATE 42P01 secret', '')
        answers = iter(['ZERO', '1\nAU1,PU0,AI1,AL1,U0'])
        fixture.db_sql = lambda _sql: next(answers)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            fixture.auth_failure_diagnostic()
        self.assertIn('AU1,PU0,AI1,AL1,U0', output.getvalue())
        self.assertNotIn('secret', output.getvalue())
        answers = iter(['ZERO', 'unexpected secret'])
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(RuntimeError, 'metadata'):
            fixture.auth_failure_diagnostic()

    def test_search_path_probe_rejects_unresolved_or_unexpected_values(self):
        fixture = runner.Fixture.__new__(runner.Fixture)
        fixture.db_sql = lambda _sql: '1\nAUTH_USERS_RESOLVED\n'
        fixture.verify_postgres_user_resolution()
        for result in ('AUTH_USERS_UNRESOLVED', 'unexpected'):
            fixture.db_sql = lambda _sql: result
            with self.assertRaisesRegex(RuntimeError, 'cannot resolve'):
                fixture.verify_postgres_user_resolution()


if __name__ == '__main__': unittest.main()
