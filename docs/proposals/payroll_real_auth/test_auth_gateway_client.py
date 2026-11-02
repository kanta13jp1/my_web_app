"""Pure unit checks; transport is synthetic and cannot access any network."""
import base64
import hmac
import json
import unittest
from unittest.mock import patch
import auth_gateway_client as client

SECRET = b'fake-fixture-secret-not-production-32-bytes'
SUBJECT = 'aaaaaaaa-0000-4000-8000-000000000001'
ISSUER = 'http://synthetic-gateway:8000/auth/v1'


def token(claims, *, secret=SECRET, header=None):
    encode = lambda b: base64.urlsafe_b64encode(b).decode().rstrip('=')
    h = encode(json.dumps(header or {'alg': 'HS256'}).encode())
    p = encode(json.dumps(claims).encode())
    sig = encode(hmac.digest(secret, (h + '.' + p).encode(), 'sha256'))
    return h + '.' + p + '.' + sig


def claims(**overrides):
    out = {'exp': 1001, 'iss': ISSUER, 'aud': 'authenticated',
           'role': 'authenticated', 'sub': SUBJECT}
    out.update(overrides)
    return out


class FakeTransport:
    def __init__(self, response):
        self.response = response
        self.calls = 0
    def request(self, method, path, headers, body):
        self.calls += 1
        if isinstance(self.response, Exception):
            raise self.response
        return self.response


class ClientTests(unittest.TestCase):
    def test_direct_entry_is_disabled(self):
        with self.assertRaises(RuntimeError):
            client.run_integration()

    def test_jwt_signature_issuer_role_subject_and_expiry(self):
        self.assertEqual(client.verify_synthetic_jwt(token(claims()), SECRET, ISSUER, SUBJECT, now=1000), SUBJECT)
        for changes in ({'role': 'service_role'}, {'sub': 'bbbbbbbb-0000-4000-8000-000000000002'},
                        {'iss': 'https://external.invalid'}, {'exp': 1000}, {'aud': 'anon'},
                        {'nbf': 1001}, {'iat': 1001}):
            with self.subTest(changes=changes), self.assertRaises(client.CheckFailed):
                client.verify_synthetic_jwt(token(claims(**changes)), SECRET, ISSUER, SUBJECT, now=1000)
        with self.assertRaises(client.CheckFailed):
            client.verify_synthetic_jwt(token(claims(), secret=b'wrong'), SECRET, ISSUER, SUBJECT, now=1000)
        with self.assertRaises(client.CheckFailed):
            client.verify_synthetic_jwt(token(claims(), header={'alg': 'none'}), SECRET, ISSUER, SUBJECT, now=1000)

    def test_write_timeout_and_server_error_are_unknown_not_retried(self):
        for response in (TimeoutError('synthetic'), (503, b'{"code":"unavailable"}'),
                         (200, b'{'), (302, b'{}'), ('200', b'{}')):
            transport = FakeTransport(response)
            subject = client.SyntheticClient(transport, 'synthetic-key', SECRET, ISSUER)
            with self.assertRaises(client.UnknownWriteResult):
                subject._request('POST', client.RPC, data={'test': True}, write=True)
            self.assertEqual(transport.calls, 1)

    def test_diagnostic_operation_and_code_are_allowlisted(self):
        for code, expected in (('unexpected_failure', 'unexpected_failure'),
                               ('secret_synthetic_value', 'unavailable')):
            transport = FakeTransport((500, json.dumps({'error_code': code,
                'message': 'never display synthetic token'}).encode()))
            subject = client.SyntheticClient(transport, 'key', SECRET, ISSUER)
            with self.assertRaises(client.UnknownWriteResult):
                subject._request('POST', '/auth/v1/signup', data={'test': True}, write=True)
            self.assertEqual(subject.last_operation, 'signup')
            self.assertEqual(subject.last_http_status, 500)
            self.assertEqual(subject.last_response_code, expected)
            self.assertEqual(transport.calls, 1)

    def test_missing_own_rows_and_foreign_rows_fail_closed(self):
        subject = client.SyntheticClient(FakeTransport((200, b'[]')), 'key', SECRET, ISSUER)
        with self.assertRaises(client.CheckFailed):
            subject.check_owner_rows(SUBJECT, 'token', 'bbbbbbbb-0000-4000-8000-000000000002')
        foreign = b'[{"user_id":"bbbbbbbb-0000-4000-8000-000000000002"}]'
        subject = client.SyntheticClient(FakeTransport((200, foreign)), 'key', SECRET, ISSUER)
        with self.assertRaises(client.CheckFailed):
            subject.check_owner_rows(SUBJECT, 'token', 'bbbbbbbb-0000-4000-8000-000000000002')

    def test_cross_update_zero_rows_alone_is_not_enough(self):
        subject = client.SyntheticClient(FakeTransport((200, b'[]')), 'key', SECRET, ISSUER)
        with patch.object(subject, '_target', side_effect=[10, 123]):
            with self.assertRaisesRegex(client.CheckFailed, 'changed victim'):
                subject.cross_write('actor', SUBJECT, 'victim', 'account')

    def test_anonymous_http_failure_is_not_an_acl_denial(self):
        subject = client.SyntheticClient(FakeTransport((500, b'{}')), 'key', SECRET, ISSUER)
        with self.assertRaises(client.CheckFailed):
            subject.check_anon()

    def test_scenario_exercises_both_cross_directions_and_anon(self):
        class FakeClient:
            def __init__(self): self.calls = []
            def signup_and_login(self, email, password):
                who = 'a' if email.startswith('fixture-a@') else 'b'
                return who, 'token-' + who
            def seed_owner(self, owner, token): return 'account-' + owner
            def set_own_target(self, owner, token, account, target):
                self.calls.append(('own', owner, target))
            def check_owner_rows(self, owner, token, other):
                return {table: [{'user_id': owner, 'synthetic': table}] for table in client.TABLES}
            def cross_write(self, token, victim, victim_token, account):
                self.calls.append(('cross', token, victim))
            def check_anon(self): self.calls.append(('anon',))
        subject = FakeClient()
        client.exercise_fixture(subject, 'synthetic-password-a', 'synthetic-password-b')
        self.assertEqual(subject.calls, [('own', 'a', 10), ('own', 'b', 20),
                          ('cross', 'token-a', 'b'), ('cross', 'token-b', 'a'), ('anon',)])

    def test_recovery_requires_both_original_tokens_and_unchanged_rows(self):
        class FakeClient:
            def __init__(self): self.calls = []; self.bad_b = False
            def check_owner_rows(self, owner, token, other):
                self.calls.append(('read', owner, token, other))
                if owner == 'b' and self.bad_b: return {}
                return {table: [{'user_id': owner, 'synthetic': table}] for table in client.TABLES}
            def cross_write(self, token, victim, victim_token, account):
                self.calls.append(('cross', token, victim, victim_token, account))
            def check_anon(self): self.calls.append(('anon',))
        subject = FakeClient()
        make = lambda owner: client._canonical({
            table: [{'user_id': owner, 'synthetic': table}] for table in client.TABLES})
        state = ('a', 'original-token-a', 'account-a', 'b', 'original-token-b',
                 'account-b', make('a'), make('b'))
        client.verify_after_recovery(subject, state)
        self.assertIn(('read', 'a', 'original-token-a', 'b'), subject.calls)
        self.assertIn(('read', 'b', 'original-token-b', 'a'), subject.calls)
        self.assertIn(('cross', 'original-token-a', 'b', 'original-token-b', 'account-b'), subject.calls)
        self.assertIn(('cross', 'original-token-b', 'a', 'original-token-a', 'account-a'), subject.calls)
        self.assertIn(('anon',), subject.calls)
        subject.bad_b = True
        with self.assertRaisesRegex(client.CheckFailed, 'owner B unavailable or changed'):
            client.verify_after_recovery(subject, state)


if __name__ == '__main__':
    unittest.main()
