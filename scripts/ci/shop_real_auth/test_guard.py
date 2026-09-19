import unittest
from pathlib import Path
import tomllib
from guard import APP, API, local_url, runtime


class IsolationGuards(unittest.TestCase):
    def test_email_login_provider_enabled_but_public_signup_disabled(self):
        config = tomllib.loads(Path(__file__).with_name('config.toml').read_text(encoding='utf-8'))
        self.assertFalse(config['auth']['enable_signup'])
        self.assertTrue(config['auth']['email']['enable_signup'])
        self.assertEqual(config['api']['schemas'], ['public'])

    def env(self):
        return dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted',
                    GITHUB_RUN_ID='1234', GITHUB_RUN_ATTEMPT='1', RUNNER_TEMP=str(Path('/tmp/runner').resolve()))

    def test_loopback_only(self):
        self.assertEqual(local_url(API, port=54321).hostname, '127.0.0.1')
        self.assertEqual(local_url(APP, port=7357).port, 7357)

    def test_reject_hosted_and_ambiguous_urls(self):
        for url in ('https://example.supabase.co', 'http://localhost:54321',
                    'http://127.0.0.1:54321@evil.test', 'http://127.0.0.1:54321/path',
                    'http://127.0.0.1:54321?redirect=evil', 'http://127.0.0.1:54321#x',
                    'http://user:secret@127.0.0.1:54321', 'http://127.0.0.1:54322'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                local_url(url, port=54321)

    def test_database_is_local(self):
        local_url('postgresql://postgres:test@127.0.0.1:54322/postgres', port=54322, database=True)
        for url in ('postgresql://postgres:test@evil.test:54322/postgres',
                    'postgresql://postgres:test@127.0.0.1:54322/production'):
            with self.assertRaises(ValueError):
                local_url(url, port=54322, database=True)

    def test_scoped_work_directory(self):
        project, path = runtime(self.env())
        self.assertEqual(project, 'hexciv-auth-1234-1')
        self.assertEqual(path.name, project)

    def test_self_hosted_and_local_are_rejected(self):
        for key, value in [('GITHUB_ACTIONS', 'false'), ('RUNNER_ENVIRONMENT', 'self-hosted'),
                           ('GITHUB_RUN_ID', '../bad'), ('GITHUB_RUN_ATTEMPT', ''),
                           ('RUNNER_TEMP', ''), ('RUNNER_TEMP', '/'), ('RUNNER_TEMP', 'relative')]:
            env = self.env() | {key: value}
            with self.subTest(key=key), self.assertRaises(ValueError):
                runtime(env)

    def test_hosted_credentials_are_rejected(self):
        for key in ('SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD', 'SUPABASE_SERVICE_ROLE_KEY',
                    'STRIPE_SECRET_KEY', 'DATABASE_URL'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                runtime(self.env() | {key: 'must-not-be-used'})

    def test_url_override_rejected(self):
        for key in ('SUPABASE_URL', 'E2E_BASE_URL'):
            with self.assertRaises(ValueError):
                runtime(self.env() | {key: 'https://example.supabase.co'})


if __name__ == '__main__':
    unittest.main()
