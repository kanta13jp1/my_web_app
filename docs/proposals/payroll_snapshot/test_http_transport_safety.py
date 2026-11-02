"""No database or network access: validate transport fixture boundaries."""
import os
import subprocess
import sys
import unittest
from uuid import uuid4

from http_transport_safety import validate_environment, validate_marker_count


class TransportFixtureSafetyTest(unittest.TestCase):
    def setUp(self):
        self.safe = {
            'GITHUB_ACTIONS': 'true',
            'PGHOST': '127.0.0.1',
            'PGPORT': '5432',
            'PGDATABASE': 'payroll_contract',
            'PGUSER': 'postgres',
            'PGPASSWORD': 'synthetic-contract-only',
            'PAYROLL_TRANSPORT_FIXTURE_TOKEN': str(uuid4()),
        }

    def test_accepts_only_the_explicit_fixture_environment(self):
        self.assertEqual(validate_environment(self.safe),
                         self.safe['PAYROLL_TRANSPORT_FIXTURE_TOKEN'])

    def test_rejects_missing_and_wrong_required_settings(self):
        for key in self.safe:
            for value in ('', 'not-the-expected-value'):
                with self.subTest(key=key, value=value):
                    env = {**self.safe, key: value}
                    with self.assertRaises(RuntimeError):
                        validate_environment(env)

    def test_rejects_libpq_connection_overrides(self):
        for key in ('PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS',
                    'PGPASSFILE'):
            with self.subTest(key=key):
                with self.assertRaises(RuntimeError):
                    validate_environment({**self.safe, key: 'not-allowed'})

    def test_missing_or_multiple_markers_are_rejected(self):
        validate_marker_count('1')
        for count in ('0', '2', '', 'invalid'):
            with self.subTest(count=count):
                with self.assertRaises(RuntimeError):
                    validate_marker_count(count)

    def test_optimized_python_is_rejected_without_connecting(self):
        # -O removes assert statements; the boundary must still fail closed.
        env = {**os.environ, **self.safe}
        for key in ('PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS',
                    'PGPASSFILE'):
            env.pop(key, None)
        code = ('import os; from http_transport_safety import validate_environment; '
                'validate_environment(os.environ)')
        result = subprocess.run([sys.executable, '-O', '-c', code], env=env,
                                capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Optimized Python disables test assertions', result.stderr)


if __name__ == '__main__':
    unittest.main()
