"""Synthetic fixture adapter; execute only inside the verified internal network."""
import base64
import hashlib
import hmac
import http.client
import json
import os
import re
import secrets
import socket
import sys
import threading
import time

sys.path.insert(0, '/tmp')
from auth_gateway_client import (CheckFailed, SyntheticClient, UnknownWriteResult,
                                 exercise_fixture, verify_after_recovery, RPC)

ISSUER = 'http://synthetic-gateway:8000/auth/v1'
LOSS_REQUEST = 'cb7e027a-d89f-4a09-a720-bc7a8fd60b25'
SAFE_ERRORS = {
    'signup failed': 'signup_failed',
    'password login failed': 'login_failed',
    'JWT claims mismatch': 'jwt_claims',
    'JWT signature mismatch': 'jwt_signature',
    'own account insert result not established; do not retry': 'account_insert',
    'own confirmation RPC result not established; do not retry': 'confirm_rpc',
    'own target update result not established; do not retry': 'target_update',
    'table response is not a complete list': 'table_read',
    'own positive or owner isolation failed': 'owner_rows',
    'foreign owner rows visible': 'foreign_visible',
    'anonymous denial not established': 'anon_denial',
    'cross-owner update result not established; do not retry': 'cross_update',
    'cross-owner RPC rejection not established; do not retry': 'cross_rpc',
    'owner A unavailable or changed after recovery': 'recovery_a',
    'owner B unavailable or changed after recovery': 'recovery_b',
    'write response inconclusive; do not retry': 'write_inconclusive',
}


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def anon_token(secret):
    header = b64(json.dumps({'alg': 'HS256', 'typ': 'JWT'}, separators=(',', ':')).encode())
    body = b64(json.dumps({'role': 'anon', 'aud': 'authenticated', 'iss': ISSUER,
                           'exp': int(time.time()) + 600}, separators=(',', ':')).encode())
    signed = (header + '.' + body).encode('ascii')
    return header + '.' + body + '.' + b64(hmac.digest(secret, signed, hashlib.sha256))


class FixtureTransport:
    def request(self, method, path, headers, body):
        if (method not in ('GET', 'POST', 'PATCH') or not isinstance(path, str)
            or not (path.startswith('/auth/v1/') or path.startswith('/rest/v1/'))
            or '\r' in path or '\n' in path or path.startswith('//')):
            raise ValueError('Unexpected synthetic request')
        connection = http.client.HTTPConnection('synthetic-gateway', 8000, timeout=10)
        try:
            connection.request(method, path, body=body, headers=headers)
            response = connection.getresponse()
            return response.status, response.read(1_000_001)
        finally:
            connection.close()


class LossTransport:
    """Single fixture HTTP write: drop downstream only; drain upstream privately."""
    def __init__(self):
        self.drop = threading.Event()
        self.forwarded = threading.Event()
        self.done = threading.Event()
        self.response = None
        self.failure = None
        self.observed_disconnect = False
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(1)
        self.port = self.listener.getsockname()[1]
        self.worker = threading.Thread(target=self._serve, daemon=True)
        self.worker.start()

    def _serve(self):
        downstream = upstream = None
        try:
            self.listener.settimeout(30)
            downstream, _ = self.listener.accept()
            downstream.settimeout(30)
            data = b''
            while b'\r\n\r\n' not in data and len(data) <= 65536:
                chunk = downstream.recv(4096)
                if not chunk: raise RuntimeError('fixture request incomplete')
                data += chunk
            header, body = data.split(b'\r\n\r\n', 1)
            lines = header.split(b'\r\n')
            if not lines[0].startswith(b'POST /rest/v1/rpc/'):
                raise RuntimeError('unexpected fixture request')
            lengths = [line.split(b':', 1)[1].strip() for line in lines[1:]
                       if line.lower().startswith(b'content-length:')]
            if len(lengths) != 1 or not lengths[0].isdigit():
                raise RuntimeError('fixture content length missing')
            length = int(lengths[0])
            if length > 65536: raise RuntimeError('fixture request too large')
            while len(body) < length:
                chunk = downstream.recv(length - len(body))
                if not chunk: raise RuntimeError('fixture body incomplete')
                body += chunk
            if len(body) != length: raise RuntimeError('fixture body length mismatch')
            upstream = socket.create_connection(('synthetic-gateway', 8000), timeout=30)
            upstream.sendall(header + b'\r\n\r\n' + body)
            self.forwarded.set()
            if not self.drop.wait(30): raise RuntimeError('fixture drop signal missing')
            downstream.shutdown(socket.SHUT_RDWR)
            downstream.close()
            downstream = None
            # Do not close upstream when the client disconnects; inspect its
            # eventual response only in memory after the DB barrier is released.
            response = http.client.HTTPResponse(upstream)
            response.begin()
            self.response = (response.status, response.read(1_000_001))
        except Exception:
            self.failure = 'fixture proxy failed'
        finally:
            if downstream: downstream.close()
            if upstream: upstream.close()
            self.listener.close()
            self.done.set()

    def request(self, method, path, headers, body):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=30)
        try:
            conn.request(method, path, body=body, headers=headers)
            result = conn.getresponse()
            return result.status, result.read(1_000_001)
        except http.client.RemoteDisconnected:
            self.observed_disconnect = True
            raise
        finally:
            conn.close()


def check_lost_response(client, state):
    a, token_a, account_a, b, token_b, _, _, _ = state
    payload = client._rpc_data(account_a)
    payload.update(p_request_id=LOSS_REQUEST, p_payroll_month='2030-02-01',
                   p_deposit_reference='synthetic:' + LOSS_REQUEST, p_deposit_date='2030-02-20')
    proxy = LossTransport()
    saved = client._transport
    client._transport = proxy
    outcome = []
    def send():
        try:
            client._request('POST', RPC, bearer=token_a, data=payload, write=True)
            outcome.append('unexpected-response')
        except UnknownWriteResult:
            outcome.append('unknown')
        except Exception:
            outcome.append('other-error')
    worker = threading.Thread(target=send, daemon=True)
    worker.start()
    if not proxy.forwarded.wait(20): raise RuntimeError('fixture request not forwarded')
    print('SYNTHETIC_WRITE_FORWARDED', flush=True)
    if sys.stdin.readline().strip() != 'SYNTHETIC_DROP_RESPONSE':
        raise RuntimeError('unexpected fixture drop command')
    proxy.drop.set()
    worker.join(20)
    if worker.is_alive() or outcome != ['unknown'] or not proxy.observed_disconnect:
        raise RuntimeError('fixture response loss not observed')
    client._transport = saved
    print('SYNTHETIC_WRITE_UNKNOWN', flush=True)
    if sys.stdin.readline().strip() != 'SYNTHETIC_DB_COMMITTED':
        raise RuntimeError('unexpected fixture commit command')
    if not proxy.done.wait(20) or proxy.failure or proxy.response is None:
        raise RuntimeError('fixture upstream response missing')
    status, raw = proxy.response
    if status != 200: raise RuntimeError('fixture upstream write failed')
    original_id = json.loads(raw)
    if not isinstance(original_id, str): raise RuntimeError('fixture upstream id missing')
    status, replay_id = client._request('POST', RPC, bearer=token_a, data=payload, write=True)
    if status != 200 or replay_id != original_id:
        raise RuntimeError('fixture same request replay mismatch')
    path = client._filter('asset_payroll_balance_observations', request_id='eq.' + LOSS_REQUEST)
    status, own = client._request('GET', path, bearer=token_a)
    status_b, foreign = client._request('GET', path, bearer=token_b)
    if status != 200 or not isinstance(own, list) or len(own) != 1 or own[0].get('id') != original_id:
        raise RuntimeError('fixture own request not unique')
    if status_b != 200 or foreign != []:
        raise RuntimeError('fixture foreign request visible')
    print('SYNTHETIC_REPLAY_VERIFIED', flush=True)


def main():
    value = os.environ.get('FIXTURE_JWT_SECRET', '')
    if not re.fullmatch(r'[0-9a-f]{64}', value):
        raise RuntimeError('Missing synthetic JWT secret')
    key = value.encode('ascii')
    client = SyntheticClient(FixtureTransport(), anon_token(key), key, ISSUER)
    try:
        state = exercise_fixture(client, secrets.token_urlsafe(24), secrets.token_urlsafe(24))
        print('SYNTHETIC_INITIAL_READY', flush=True)
        if sys.stdin.readline().strip() != 'SYNTHETIC_RESTORED':
            raise RuntimeError('Unexpected synthetic recovery signal')
        verify_after_recovery(client, state)
        print('SYNTHETIC_RECOVERY_VERIFIED', flush=True)
        if sys.stdin.readline().strip() != 'SYNTHETIC_START_WRITE':
            raise RuntimeError('Unexpected synthetic write signal')
        check_lost_response(client, state)
    except CheckFailed as error:
        category = SAFE_ERRORS.get(str(error), 'other_check')
        status = client.last_http_status or 0
        print(f'SYNTHETIC_CLIENT_ERROR:{category}:{client.last_operation}:{status:03d}:{client.last_response_code}', flush=True)
        raise SystemExit(1) from None
    except Exception:
        print('SYNTHETIC_CLIENT_ERROR:unexpected:other:000:unavailable', flush=True)
        raise SystemExit(1) from None


if __name__ == '__main__': main()
