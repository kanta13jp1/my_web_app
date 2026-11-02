"""Unconnected synthetic Auth/gateway test client; not a production tool.

This module has no network implementation. A separately reviewed fixture must
provide a transport bound exclusively to an attested disposable gateway.
Running the file directly is intentionally disabled.
"""
import base64
import hashlib
import hmac
import json
import time
import uuid
from urllib.parse import urlencode

TABLES = (
    'asset_payroll_accounts', 'asset_payroll_balance_observations',
    'asset_payroll_balance_selections', 'asset_payroll_balance_selection_history',
)
ACCOUNT = TABLES[0]
RPC = '/rest/v1/rpc/confirm_payroll_balance_observation'


class CheckFailed(Exception):
    pass


class UnknownWriteResult(CheckFailed):
    """A write returned no usable response; callers must never auto-retry."""


def require(condition, message):
    if not condition:
        raise CheckFailed(message)


def _decode_part(part):
    require(isinstance(part, str) and len(part) <= 8192, 'invalid JWT part')
    try:
        return base64.b64decode(part + '=' * (-len(part) % 4), altchars=b'-_', validate=True)
    except Exception as error:
        raise CheckFailed('invalid JWT encoding') from None


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def verify_synthetic_jwt(token, secret, issuer, user_id, now=None):
    """Verify only the deliberately configured fixture HS256 token contract."""
    require(isinstance(token, str) and isinstance(secret, bytes) and len(secret) >= 32
            and isinstance(user_id, str),
            'invalid fixture token or secret')
    parts = token.split('.')
    require(len(parts) == 3, 'invalid JWT shape')
    try:
        header = json.loads(_decode_part(parts[0]), object_pairs_hook=_unique_object)
        claims = json.loads(_decode_part(parts[1]), object_pairs_hook=_unique_object)
        signature = _decode_part(parts[2])
    except (ValueError, TypeError):
        raise CheckFailed('invalid JWT content') from None
    require(isinstance(header, dict) and header.get('alg') == 'HS256' and
            isinstance(claims, dict), 'unexpected JWT algorithm')
    expected = hmac.digest(secret, (parts[0] + '.' + parts[1]).encode('ascii'), 'sha256')
    require(hmac.compare_digest(signature, expected), 'JWT signature mismatch')
    clock = int(time.time()) if now is None else now
    exp = claims.get('exp')
    require(type(exp) is int and exp > clock, 'expired JWT')
    for key in ('iat', 'nbf'):
        if key in claims:
            require(type(claims[key]) is int and claims[key] <= clock, 'JWT not yet valid')
    require(claims.get('iss') == issuer and claims.get('aud') == 'authenticated'
            and claims.get('role') == 'authenticated' and claims.get('sub') == user_id,
            'JWT claims mismatch')
    try:
        require(str(uuid.UUID(user_id)) == user_id, 'noncanonical subject')
    except (ValueError, TypeError):
        raise CheckFailed('invalid subject') from None
    return user_id


class SyntheticClient:
    """Calls a supplied fixture transport; never logs bodies, IDs or tokens.

    Transport contract: request(method, path, headers, body_bytes_or_none)
    returns (HTTP status int, raw response bytes). Transport must independently
    prove network containment, gateway identity and fixture DB identity.
    """

    def __init__(self, transport, anon_key, jwt_secret, expected_issuer):
        require(hasattr(transport, 'request') and isinstance(anon_key, str)
                and bool(anon_key) and isinstance(jwt_secret, bytes), 'invalid fixture client')
        self._transport = transport
        self._anon = anon_key
        self._secret = jwt_secret
        self._issuer = expected_issuer

    def _request(self, method, path, *, bearer=None, data=None, write=False):
        headers = {'apikey': self._anon, 'Authorization': 'Bearer ' + (bearer or self._anon),
                   'Accept': 'application/json'}
        body = None
        if data is not None:
            headers['Content-Type'] = 'application/json'
            body = json.dumps(data, separators=(',', ':')).encode('utf-8')
        if method in ('POST', 'PATCH') and path.startswith('/rest/v1/'):
            headers['Prefer'] = 'return=representation'
        try:
            status, raw = self._transport.request(method, path, headers, body)
        except Exception:
            if write:
                raise UnknownWriteResult('write response unavailable; do not retry') from None
            raise CheckFailed('read or sign-in transport failed') from None
        if type(status) is not int or not isinstance(raw, bytes) or len(raw) > 1_000_000:
            if write:
                raise UnknownWriteResult('write response envelope invalid; do not retry')
            raise CheckFailed('invalid response envelope')
        if write and (300 <= status <= 399 or status in (408, 425, 429) or 500 <= status <= 599):
            raise UnknownWriteResult('write response inconclusive; do not retry')
        try:
            parsed = json.loads(raw) if raw else None
        except (ValueError, UnicodeError):
            if write:
                raise UnknownWriteResult('write response unparsable; do not retry') from None
            raise CheckFailed('response JSON invalid') from None
        return status, parsed

    def signup_and_login(self, email, password):
        require(email in ('fixture-a@example.invalid', 'fixture-b@example.invalid')
                and isinstance(password, str) and len(password) >= 16, 'invalid synthetic credentials')
        payload = {'email': email, 'password': password}
        status, _ = self._request('POST', '/auth/v1/signup', data=payload, write=True)
        require(status in (200, 201), 'signup failed')
        status, value = self._request('POST', '/auth/v1/token?grant_type=password', data=payload)
        require(status == 200 and isinstance(value, dict) and isinstance(value.get('user'), dict),
                'password login failed')
        subject = value['user'].get('id')
        verify_synthetic_jwt(value.get('access_token'), self._secret, self._issuer, subject)
        return subject, value['access_token']

    def _filter(self, table, **filters):
        require(table in TABLES, 'unexpected fixture table')
        return '/rest/v1/' + table + '?' + urlencode({'select': '*', **filters})

    def _rows(self, owner_token, table, **filters):
        status, rows = self._request('GET', self._filter(table, **filters), bearer=owner_token)
        require(status == 200 and isinstance(rows, list) and all(isinstance(x, dict) for x in rows),
                'table response is not a complete list')
        return rows

    def _rpc_data(self, account_id):
        request_id = str(uuid.uuid4())
        return {'p_account_id': account_id, 'p_payroll_month': '2030-01-01',
                'p_deposit_reference': 'synthetic:' + request_id, 'p_deposit_date': '2030-01-20',
                'p_date_precision': 'day', 'p_deposited_at': None, 'p_observed_at': None,
                'p_balance_yen': 100, 'p_source_note': 'synthetic', 'p_request_id': request_id,
                'p_expected_previous_id': None, 'p_reason': 'synthetic', 'p_confirm_immediate': True}

    def seed_owner(self, subject, token):
        account_id = str(uuid.uuid4())
        status, rows = self._request('POST', '/rest/v1/' + ACCOUNT, bearer=token, write=True,
            data={'user_id': subject, 'id': account_id, 'display_label': 'synthetic account'})
        if not (status == 201 and isinstance(rows, list) and len(rows) == 1
                and isinstance(rows[0], dict) and rows[0].get('id') == account_id
                and rows[0].get('user_id') == subject):
            raise UnknownWriteResult('own account insert result not established; do not retry')
        status, observation = self._request('POST', RPC, bearer=token,
                                            data=self._rpc_data(account_id), write=True)
        if not (status == 200 and isinstance(observation, str)):
            raise UnknownWriteResult('own confirmation RPC result not established; do not retry')
        return account_id

    def check_owner_rows(self, subject, token, other_subject):
        snapshot = {}
        for table in TABLES:
            rows = self._rows(token, table)
            require(len(rows) == 1 and all(row.get('user_id') == subject for row in rows),
                    'own positive or owner isolation failed')
            require(self._rows(token, table, user_id='eq.' + other_subject) == [],
                    'foreign owner rows visible')
            snapshot[table] = rows
        return snapshot

    def _target(self, subject, token, account_id):
        rows = self._rows(token, ACCOUNT, user_id='eq.' + subject, id='eq.' + account_id)
        require(len(rows) == 1 and 'target_increase_yen' in rows[0], 'own account missing')
        return rows[0]['target_increase_yen']

    def set_own_target(self, subject, token, account_id, target):
        path = self._filter(ACCOUNT, user_id='eq.' + subject, id='eq.' + account_id)
        status, rows = self._request('PATCH', path, bearer=token, write=True,
                                     data={'target_increase_yen': target})
        if not (status == 200 and isinstance(rows, list) and len(rows) == 1
                and isinstance(rows[0], dict) and rows[0].get('user_id') == subject
                and rows[0].get('id') == account_id and rows[0].get('target_increase_yen') == target):
            raise UnknownWriteResult('own target update result not established; do not retry')
        require(self._target(subject, token, account_id) == target, 'own target reread failed')

    def cross_write(self, actor_token, victim_subject, victim_token, victim_id):
        before = self._target(victim_subject, victim_token, victim_id)
        path = self._filter(ACCOUNT, user_id='eq.' + victim_subject, id='eq.' + victim_id)
        status, rows = self._request('PATCH', path, bearer=actor_token, write=True,
                                     data={'target_increase_yen': 123})
        if status != 200 or rows != []:
            raise UnknownWriteResult('cross-owner update result not established; do not retry')
        require(self._target(victim_subject, victim_token, victim_id) == before,
                'cross-owner update changed victim target')
        status, error = self._request('POST', RPC, bearer=actor_token,
                                      data=self._rpc_data(victim_id), write=True)
        if status != 403 or not isinstance(error, dict) or error.get('code') != '42501':
            raise UnknownWriteResult('cross-owner RPC rejection not established; do not retry')
        require(self._target(victim_subject, victim_token, victim_id) == before,
                'cross-owner RPC changed victim target')

    def check_anon(self):
        for path in [*(self._filter(table) for table in TABLES), RPC]:
            method = 'POST' if path == RPC else 'GET'
            status, error = self._request(method, path,
                data=self._rpc_data(str(uuid.uuid4())) if method == 'POST' else None,
                write=method == 'POST')
            require(status in (401, 403) and isinstance(error, dict) and error.get('code') == '42501',
                    'anonymous denial not established')


def _canonical(snapshot):
    return {table: sorted(json.dumps(row, sort_keys=True, separators=(',', ':'))
                          for row in rows) for table, rows in snapshot.items()}


def exercise_fixture(client, password_a, password_b):
    """Only call after a separately reviewed transport attests fixture identity."""
    a, token_a = client.signup_and_login('fixture-a@example.invalid', password_a)
    b, token_b = client.signup_and_login('fixture-b@example.invalid', password_b)
    require(a != b, 'fixture owners are not distinct')
    account_a = client.seed_owner(a, token_a)
    account_b = client.seed_owner(b, token_b)
    client.set_own_target(a, token_a, account_a, 10)
    client.set_own_target(b, token_b, account_b, 20)
    before_a = _canonical(client.check_owner_rows(a, token_a, b))
    before_b = _canonical(client.check_owner_rows(b, token_b, a))
    client.cross_write(token_a, b, token_b, account_b)
    client.cross_write(token_b, a, token_a, account_a)
    client.check_anon()
    require(_canonical(client.check_owner_rows(a, token_a, b)) == before_a,
            'owner A changed after negative attempts')
    require(_canonical(client.check_owner_rows(b, token_b, a)) == before_b,
            'owner B changed after negative attempts')
    # The caller keeps this only in the isolated client's memory, never logs it.
    return (a, token_a, account_a, b, token_b, account_b, before_a, before_b)


def verify_after_recovery(client, state):
    """Recheck both original real tokens and all rows after gateway recovery."""
    a, token_a, account_a, b, token_b, account_b, before_a, before_b = state
    require(_canonical(client.check_owner_rows(a, token_a, b)) == before_a,
            'owner A unavailable or changed after recovery')
    require(_canonical(client.check_owner_rows(b, token_b, a)) == before_b,
            'owner B unavailable or changed after recovery')
    client.cross_write(token_a, b, token_b, account_b)
    client.cross_write(token_b, a, token_a, account_a)
    client.check_anon()
    require(_canonical(client.check_owner_rows(a, token_a, b)) == before_a,
            'owner A changed after recovery negatives')
    require(_canonical(client.check_owner_rows(b, token_b, a)) == before_b,
            'owner B changed after recovery negatives')


def run_integration():
    raise RuntimeError('Disabled: reviewed isolated transport and fixture attestation required')


if __name__ == '__main__':
    run_integration()
