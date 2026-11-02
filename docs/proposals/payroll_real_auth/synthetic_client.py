"""Synthetic fixture adapter; execute only inside the verified internal network."""
import base64
import hashlib
import hmac
import http.client
import json
import os
import re
import secrets
import sys
import time

sys.path.insert(0, '/tmp')
from auth_gateway_client import SyntheticClient, exercise_fixture, verify_after_recovery

ISSUER = 'http://synthetic-gateway:8000/auth/v1'


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


def main():
    value = os.environ.get('FIXTURE_JWT_SECRET', '')
    if not re.fullmatch(r'[0-9a-f]{64}', value):
        raise RuntimeError('Missing synthetic JWT secret')
    key = value.encode('ascii')
    client = SyntheticClient(FixtureTransport(), anon_token(key), key, ISSUER)
    state = exercise_fixture(client, secrets.token_urlsafe(24), secrets.token_urlsafe(24))
    print('SYNTHETIC_INITIAL_READY', flush=True)
    if sys.stdin.readline().strip() != 'SYNTHETIC_RESTORED':
        raise RuntimeError('Unexpected synthetic recovery signal')
    verify_after_recovery(client, state)
    print('SYNTHETIC_RECOVERY_VERIFIED', flush=True)


if __name__ == '__main__': main()
