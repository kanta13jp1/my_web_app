import os
import unittest
from unittest.mock import patch
import registry_atomic_test as target


class IsolationGuardTest(unittest.TestCase):
    def test_rejects_unsafe_environment_before_sql(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(target, 'sql') as sql:
            with self.assertRaises(RuntimeError):
                target.main()
            sql.assert_not_called()

    def test_accepts_only_exact_ci_service_configuration(self):
        safe = {
            'GITHUB_ACTIONS': 'true', 'PGHOST': 'localhost',
            'PGPORT': '5432', 'PGUSER': 'postgres',
            'PGPASSWORD': 'registry-ci-only',
        }
        with patch.dict(os.environ, safe, clear=True):
            target.require_isolated_ci()
        for key in safe:
            bad = dict(safe, **{key: 'unexpected'})
            with self.subTest(key=key), patch.dict(os.environ, bad, clear=True):
                with self.assertRaises(RuntimeError):
                    target.require_isolated_ci()


if __name__ == '__main__':
    unittest.main()
