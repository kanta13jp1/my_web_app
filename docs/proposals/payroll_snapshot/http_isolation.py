"""Synthetic PostgREST+Postgres HTTP isolation, never a production endpoint.

The signed tokens, account IDs and balances below are fixtures only. This
checks PostgREST's role/claim forwarding against a disposable database; it
does not prove Supabase Auth, Kong, or the deployed project's configuration.
"""
import base64
import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.request


BASE = 'http://127.0.0.1:31337'
SECRET = os.environ['SYNTHETIC_JWT_SECRET'].encode()
A = 'aaaaaaaa-0000-0000-0000-000000000001'
B = 'bbbbbbbb-0000-0000-0000-000000000002'
ACCOUNT_A = 'aaaaaaaa-1111-1111-1111-111111111111'
TABLES = (
    'asset_payroll_accounts',
    'asset_payroll_balance_observations',
    'asset_payroll_balance_selections',
    'asset_payroll_balance_selection_history',
)


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b'=')


def token(subject):
    header = b64(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
    claims = b64(json.dumps({'role': 'authenticated', 'sub': subject,
                             'exp': int(time.time()) + 300}).encode())
    signing_input = header + b'.' + claims
    return (signing_input + b'.' + b64(hmac.new(SECRET, signing_input,
                                                hashlib.sha256).digest())).decode()


def request(path, subject=None, method='GET', payload=None, profile=None):
    headers = {'Accept': 'application/json'}
    if subject:
        headers['Authorization'] = 'Bearer ' + token(subject)
    if profile:
        headers['Accept-Profile'] = profile
    body = None
    if payload is not None:
        headers['Content-Type'] = 'application/json'
        body = json.dumps(payload).encode()
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status, json.loads(resp.read() or b'null')
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read() or b'null')


for attempt in range(40):
    try:
        status, _ = request('/')
        if status == 200:
            break
    except (OSError, ValueError):
        pass
    time.sleep(.5)
else:
    raise AssertionError('synthetic PostgREST did not become ready')

for table in TABLES:
    status, own = request('/' + table + '?select=*', A)
    assert status == 200 and own, (table, 'owner fixture missing', status)
    status, foreign = request('/' + table + '?select=*', B)
    assert status == 200 and foreign == [], (table, 'foreign rows visible', status)
    status, _ = request('/' + table + '?select=*')
    assert status in (401, 403), (table, 'anonymous read unexpectedly allowed', status)
print('PASS: synthetic authenticated A sees fixtures; B and anon cannot read them')

payload = {
    'p_account_id': ACCOUNT_A, 'p_payroll_month': '2030-06-01',
    'p_deposit_reference': 'synthetic-http', 'p_deposit_date': '2030-06-20',
    'p_date_precision': 'day', 'p_deposited_at': None, 'p_observed_at': None,
    'p_balance_yen': 500, 'p_source_note': 'synthetic',
    'p_request_id': '00000000-0000-0000-0000-000000000060',
    'p_expected_previous_id': None, 'p_reason': 'synthetic',
    'p_confirm_immediate': True,
}
status, result = request('/rpc/confirm_payroll_balance_observation', B, 'POST', payload)
assert status == 403 and result.get('code') == '42501', ('foreign RPC', status, result)
status, own_id = request('/rpc/confirm_payroll_balance_observation', A, 'POST', payload)
assert status == 200 and isinstance(own_id, str), ('owner RPC failed', status, own_id)
status, retry_id = request('/rpc/confirm_payroll_balance_observation', A, 'POST', payload)
assert status == 200 and retry_id == own_id, ('owner retry not idempotent', status)
status, foreign = request('/asset_payroll_balance_observations?select=*', B)
assert status == 200 and foreign == [], ('foreign observation after RPC', status)
print('PASS: synthetic B cannot call A RPC; A retry preserves its observation')

for subject in (None, A, B):
    status, result = request('/__synthetic_missing__?select=*', subject,
                             profile='payroll_snapshot_private')
    assert status == 406 and result.get('code') == 'PGRST106', ('private schema exposed', status)
print('PASS: synthetic private schema rejected for anon and authenticated profiles')
