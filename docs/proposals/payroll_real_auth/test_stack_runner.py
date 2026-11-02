"""Pure checks only; never starts a fixture or opens a socket."""
import hashlib
import json
from pathlib import Path
import queue
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


if __name__ == '__main__': unittest.main()
