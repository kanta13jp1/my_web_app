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
import re
import subprocess
import time
import urllib.error
import urllib.request


if not __debug__:
    raise SystemExit('Optimized Python would disable required assertions')
if (os.environ.get('GITHUB_ACTIONS') != 'true' or
        os.environ.get('PAYROLL_HTTP_ISOLATION') != 'explicit-synthetic-http-fixture'):
    raise SystemExit('Explicit GitHub Actions synthetic HTTP fixture required')
container = os.environ.get('PAYROLL_HTTP_CONTAINER', '')
expected_container = 'payroll-http-{}-{}'.format(
    os.environ.get('GITHUB_RUN_ID', ''), os.environ.get('GITHUB_RUN_ATTEMPT', ''))
if container != expected_container or container == 'payroll-http--':
    raise SystemExit('Expected owned synthetic container is required')
inspection = subprocess.run(
    ['docker', 'inspect', container],
    capture_output=True, text=True, check=True, timeout=5,
).stdout.strip()
metadata = json.loads(inspection)
if len(metadata) != 1:
    raise SystemExit('Exactly one owned synthetic container is required')
config = metadata[0]
container_env = dict(item.split('=', 1) for item in config['Config']['Env'] if '=' in item)
expected_env = {
    'PGRST_DB_URI': 'postgres://payroll_http_authenticator:synthetic-http-only@localhost:5432/payroll_contract',
    'PGRST_DB_SCHEMAS': 'public', 'PGRST_DB_ANON_ROLE': 'anon',
    'PGRST_SERVER_HOST': '127.0.0.1', 'PGRST_SERVER_PORT': '31337',
    'PGRST_JWT_SECRET': os.environ.get('SYNTHETIC_JWT_SECRET', ''),
}
if (config['Config']['Image'] != 'postgrest/postgrest@sha256:5f4ce744539bbba786b4e24dbbd95bdb2a956dcf568c5374995a0ff4a68f5bd2'
        or not config['State']['Running'] or config['HostConfig']['NetworkMode'] != 'host'
        or any(container_env.get(key) != value for key, value in expected_env.items())):
    raise SystemExit('Expected owned pinned synthetic PostgREST container is required')
nonce = os.environ.get('PAYROLL_HTTP_NONCE', '')
if not re.fullmatch('[0-9a-f]{64}', nonce):
    raise SystemExit('Expected a fresh synthetic database marker')

BASE = 'http://127.0.0.1:31337'
SECRET = os.environ['SYNTHETIC_JWT_SECRET'].encode()
A = 'aaaaaaaa-0000-0000-0000-000000000001'
B = 'bbbbbbbb-0000-0000-0000-000000000002'
ACCOUNT_A = 'aaaaaaaa-1111-1111-1111-111111111111'
ACCOUNT_B = 'bbbbbbbb-1111-1111-1111-111111111111'
TABLES = (
    'asset_payroll_accounts',
    'asset_payroll_balance_observations',
    'asset_payroll_balance_selections',
    'asset_payroll_balance_selection_history',
)


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b'=')


def token(subject, secret=SECRET):
    header = b64(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
    claims = b64(json.dumps({'role': 'authenticated', 'sub': subject,
                             'exp': int(time.time()) + 300}).encode())
    signing_input = header + b'.' + claims
    return (signing_input + b'.' + b64(hmac.new(secret, signing_input,
                                                hashlib.sha256).digest())).decode()


def request(path, subject=None, method='GET', payload=None, profile=None, bearer=None):
    headers = {'Accept': 'application/json'}
    if bearer is not None:
        headers['Authorization'] = 'Bearer ' + bearer
    elif subject:
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

status, marker = request('/payroll_http_fixture_marker?select=nonce', A)
assert status == 200 and marker == [{'nonce': nonce}], 'Wrong synthetic HTTP/database fixture'

for table in TABLES:
    status, own = request('/' + table + '?select=*', A)
    assert status == 200 and own, (table, 'owner fixture missing', status)
    status, foreign = request('/' + table + '?select=*', B)
    assert status == 200 and foreign == [], (table, 'foreign rows visible', status)
    status, _ = request('/' + table + '?select=*')
    assert status in (401, 403), (table, 'anonymous read unexpectedly allowed', status)
print('PASS: synthetic authenticated A sees fixtures; B and anon cannot read them')

# A syntactically valid JWT with a forged signature cannot select A's role.
status, _ = request('/asset_payroll_accounts?select=*',
                    bearer=token(A, b'incorrect-synthetic-key-0123456789'))
assert status == 401, ('invalid signature unexpectedly accepted', status)

# B may create its own synthetic account, but cannot impersonate A or update
# A's account. Test the reverse direction after establishing B's fixture too.
status, _ = request('/asset_payroll_accounts', B, 'POST', {
    'user_id': B, 'id': ACCOUNT_B, 'display_label': 'Synthetic B account',
})
assert status == 201, ('B own account creation failed', status)
status, _ = request('/asset_payroll_accounts', B, 'POST', {
    'user_id': A, 'id': 'cccccccc-1111-1111-1111-111111111111',
    'display_label': 'forged synthetic account',
})
assert status == 403, ('forged account unexpectedly created', status)
for owner, own_id in ((A, ACCOUNT_A), (B, ACCOUNT_B)):
    status, visible = request('/asset_payroll_accounts?select=id', owner)
    assert status == 200 and {row['id'] for row in visible} == {own_id}, (
        'mixed-owner account isolation failed', status)
for actor, owner, account in ((B, A, ACCOUNT_A), (A, B, ACCOUNT_B)):
    path = '/asset_payroll_accounts?id=eq.' + account
    status, original = request(path + '&select=display_label', owner)
    assert status == 200 and len(original) == 1, ('owner fixture missing', status)
    status, _ = request(path, actor, 'PATCH', {'display_label': 'foreign modification'})
    assert status == 204, ('foreign update should affect zero rows', status)
    status, after = request(path + '&select=display_label', owner)
    assert status == 200 and after == original, ('foreign update changed owner row', status)
    status, _ = request(path, actor, 'DELETE')
    assert status in (401, 403), ('foreign delete unexpectedly allowed', status)
    status, after_delete = request(path + '&select=display_label', owner)
    assert status == 200 and after_delete == original, ('foreign delete changed owner row', status)
print('PASS: invalid JWT, owner spoofing and cross-owner HTTP updates rejected')

payload = {
    'p_account_id': ACCOUNT_A, 'p_payroll_month': '2030-06-01',
    'p_deposit_reference': 'synthetic-http', 'p_deposit_date': '2030-06-20',
    'p_date_precision': 'day', 'p_deposited_at': None, 'p_observed_at': None,
    'p_balance_yen': 500, 'p_source_note': 'synthetic',
    'p_request_id': '00000000-0000-0000-0000-000000000060',
    'p_expected_previous_id': None, 'p_reason': 'synthetic',
    'p_confirm_immediate': True,
}
status, result = request('/rpc/confirm_payroll_balance_observation', None, 'POST', payload)
assert status in (401, 403) and result.get('code') == '42501', ('anonymous RPC allowed', status)
status, result = request('/rpc/confirm_payroll_balance_observation', B, 'POST', payload)
assert status == 403 and result.get('code') == '42501', ('foreign RPC', status, result)
status, own_id = request('/rpc/confirm_payroll_balance_observation', A, 'POST', payload)
assert status == 200 and isinstance(own_id, str), ('owner RPC failed', status, own_id)
status, retry_id = request('/rpc/confirm_payroll_balance_observation', A, 'POST', payload)
assert status == 200 and retry_id == own_id, ('owner retry not idempotent', status)
status, foreign = request('/asset_payroll_balance_observations?select=*', B)
assert status == 200 and foreign == [], ('foreign observation after RPC', status)
print('PASS: synthetic B cannot call A RPC; A retry preserves its observation')

# Populate B using its own authenticated RPC, then check mutual isolation with
# both owners present in all four tables, including the audit/selection rows.
payload_b = dict(payload, p_account_id=ACCOUNT_B,
                 p_request_id='00000000-0000-0000-0000-000000000061')
status, b_id = request('/rpc/confirm_payroll_balance_observation', B, 'POST', payload_b)
assert status == 200 and isinstance(b_id, str), ('B own RPC failed', status)
for table in TABLES:
    for subject in (A, B):
        status, rows = request('/' + table + '?select=user_id', subject)
        assert status == 200 and rows and all(row['user_id'] == subject for row in rows), (
            table, 'mixed-owner row isolation failed', status)
print('PASS: synthetic A and B each see only their own rows across all four tables')

for subject in (None, A, B):
    status, result = request('/__synthetic_missing__?select=*', subject,
                             profile='payroll_snapshot_private')
    assert status == 406 and result.get('code') == 'PGRST106', ('private schema exposed', status)
print('PASS: synthetic private schema rejected for anon and authenticated profiles')
