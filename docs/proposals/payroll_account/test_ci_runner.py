"""Offline safety and source checks only; never runs Docker or PostgreSQL."""
import copy
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import ci_runner as runner


def sample():
    return {'Id': 'a' * 64, 'Image': 'sha256:' + 'b' * 64,
            'State': {'Running': True}, 'Config': {'Image': runner.IMAGE,
                'Labels': {'payroll.synthetic.run': '123-1'},
                'Env': ['POSTGRES_DB=payroll_contract', 'POSTGRES_PASSWORD=synthetic-account-only']},
            'HostConfig': {'NetworkMode': 'fixture-network', 'Privileged': False,
                           'Binds': None, 'PortBindings': None,
                           'Tmpfs': {'/var/lib/postgresql/data': 'rw'}},
            'Mounts': []}


class SafetyTests(unittest.TestCase):
    def test_fixed_sources_and_review_stops(self):
        sources = runner.load_sources()
        self.assertEqual(set(sources), set(runner.FIXED))
        self.assertNotIn(runner.RPC_STOP, sources['rpc.sql.disabled'])
        self.assertNotIn(runner.ACL_STOP, sources['acl.sql.disabled'])

    def test_changed_source_fails_closed(self):
        with tempfile.TemporaryDirectory() as root:
            sql = Path(root, 'sql')
            sql.mkdir()
            (sql / 'fixture').write_text('changed', encoding='utf-8')
            with patch.object(runner, 'HERE', Path(root)), patch.object(
                runner, 'FIXED', {'fixture': hashlib.sha256(b'original').hexdigest()}):
                with self.assertRaisesRegex(RuntimeError, 'hash mismatch'):
                    runner.load_sources()

    def test_unrecognized_or_repeated_stop_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            sql = Path(root, 'sql')
            sql.mkdir()
            raw = (runner.TEST_STOP * 2).encode()
            (sql / 'fixture').write_bytes(raw)
            with patch.object(runner, 'HERE', Path(root)), patch.object(
                runner, 'FIXED', {'fixture': hashlib.sha256(raw).hexdigest()}):
                with self.assertRaisesRegex(RuntimeError, 'stop'):
                    runner.load_sources()

    def test_ci_and_container_id_required_before_any_process(self):
        with patch.object(runner.subprocess, 'run', side_effect=AssertionError('process called')):
            valid = {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted',
                     'GITHUB_REPOSITORY': 'kanta13jp1/my_web_app', 'GITHUB_JOB': 'synthetic-postgres',
                     'GITHUB_EVENT_NAME': 'pull_request', 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1'}
            for env in ({}, {'GITHUB_ACTIONS': 'true'},
                        dict(valid, FIXTURE_CONTAINER_ID='../prod')):
                with self.assertRaises(RuntimeError):
                    runner.Service(env)

    def test_container_rejects_wrong_identity_and_host_exposure(self):
        self.assertTrue(runner.container_ok(sample(), 'a' * 64, 'sha256:' + 'b' * 64, '123-1'))
        for change in ('id', 'image', 'running', 'host', 'privileged', 'bind', 'port', 'tmpfs', 'volume', 'label', 'db'):
            info = copy.deepcopy(sample())
            if change == 'id': info['Id'] = 'c' * 64
            if change == 'image': info['Config']['Image'] = 'postgres:17-alpine'
            if change == 'running': info['State']['Running'] = False
            if change == 'host': info['HostConfig']['NetworkMode'] = 'host'
            if change == 'privileged': info['HostConfig']['Privileged'] = True
            if change == 'bind': info['HostConfig']['Binds'] = ['/private:/fixture']
            if change == 'port': info['HostConfig']['PortBindings'] = {'5432/tcp': []}
            if change == 'tmpfs': info['HostConfig']['Tmpfs'] = {}
            if change == 'volume': info['Mounts'] = [{'Type': 'volume', 'Destination': '/other'}]
            if change == 'label': info['Config']['Labels']['payroll.synthetic.run'] = '999-1'
            if change == 'db': info['Config']['Env'] = []
            with self.subTest(change=change):
                self.assertFalse(runner.container_ok(info, 'a' * 64, 'sha256:' + 'b' * 64, '123-1'))

    def test_nonempty_database_fails_before_initialization(self):
        class FakeService:
            def __init__(self): self.calls = []
            def sql(self, source, guard=True):
                self.calls.append((source, guard))
                return 'NOT_EMPTY\n'
        service = FakeService()
        with self.assertRaisesRegex(RuntimeError, 'empty synthetic'):
            runner.execute(service, {})
        self.assertEqual(len(service.calls), 1)
        self.assertIn('EMPTY_FIXTURE', service.calls[0][0])
        self.assertFalse(service.calls[0][1])

    def test_owner_fixture_has_positive_negative_and_rollback_boundaries(self):
        text = runner.load_sources()['owner-rls.sql.disabled'].lower()
        for label in ('owner c positive rows missing', 'owner d positive rows missing',
                      'owner c can read owner d rows', 'owner d can read owner c rows',
                      'owner c updated owner d target', 'owner d updated owner c target',
                      'owner c foreign account rpc unexpectedly succeeded',
                      'owner d foreign account rpc unexpectedly succeeded',
                      'anon account select unexpectedly succeeded',
                      'anon observation select unexpectedly succeeded',
                      'anon selection select unexpectedly succeeded',
                      'anon history select unexpectedly succeeded',
                      'anon rpc unexpectedly succeeded', 'synthetic owner post-state differs'):
            self.assertIn(label, text)
        self.assertTrue(text.rstrip().endswith('rollback;'))


if __name__ == '__main__':
    unittest.main()
