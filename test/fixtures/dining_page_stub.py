"""Loopback-only read fixture. Synthetic identities; never proxies or stores data."""
import base64
from datetime import datetime, timezone
import hashlib
import hmac
import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlsplit

USERS = {
    'fixture-a@example.invalid': '11111111-1111-4111-8111-111111111111',
    'fixture-b@example.invalid': '22222222-2222-4222-8222-222222222222',
}
PASSWORD = 'fixture-password-only'
KEY = b'public-synthetic-test-key-not-a-real-secret'
COUNTS = {'auth': 0, 'flows_a': 0, 'flows_b': 0, 'reflection_a': 0, 'reflection_b': 0,
          'rejected_writes': 0, 'rejected_identity': 0}


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def token(user_id):
    header = b64(b'{"alg":"HS256","typ":"JWT"}')
    claims = b64(json.dumps({'sub': user_id, 'aud': 'authenticated',
                             'role': 'authenticated', 'exp': 4102444800},
                            separators=(',', ':')).encode())
    signed = (header + '.' + claims).encode()
    return signed.decode() + '.' + b64(hmac.new(KEY, signed, hashlib.sha256).digest())


def dispatch(method, target, headers, body=b''):
    url = urlsplit(target)
    query = parse_qs(url.query)
    if method == 'OPTIONS':
        return 204, None
    if method == 'GET' and url.path == '/__fixture_status':
        return 200, dict(COUNTS)
    if method == 'POST' and url.path == '/auth/v1/token' and query == {'grant_type': ['password']}:
        try:
            credentials = json.loads(body)
        except (ValueError, UnicodeDecodeError):
            credentials = {}
        if not isinstance(credentials, dict):
            credentials = {}
        email = credentials.get('email')
        if set(credentials) != {'email', 'password', 'gotrue_meta_security'} and set(credentials) != {'email', 'password'}:
            COUNTS['rejected_identity'] += 1
            return 403, {'error': 'fixture identity rejected'}
        if email not in USERS or credentials.get('password') != PASSWORD:
            COUNTS['rejected_identity'] += 1
            return 403, {'error': 'fixture identity rejected'}
        user_id = USERS[email]
        COUNTS['auth'] += 1
        user = {'id': user_id, 'aud': 'authenticated', 'role': 'authenticated',
                'email': email, 'app_metadata': {}, 'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z'}
        return 200, {'access_token': token(user_id), 'token_type': 'bearer',
                     'expires_in': 3600, 'refresh_token': 'fixture-refresh-' + user_id,
                     'user': user}
    if method != 'GET':
        COUNTS['rejected_writes'] += 1
        return 403, {'error': 'fixture rejects writes'}
    if url.path not in {'/rest/v1/wealth_struggles', '/rest/v1/asset_calendar_reflections'}:
        return 404, {'error': 'fixture route not implemented'}
    owner = next((user_id for user_id in USERS.values()
                  if headers.get('authorization') == 'Bearer ' + token(user_id)), None)
    if owner is None or query.get('user_id') != ['eq.' + owner]:
        COUNTS['rejected_identity'] += 1
        return 403, {'error': 'fixture owner rejected'}
    if url.path.endswith('asset_calendar_reflections'):
        key = 'reflection_a' if owner == USERS['fixture-a@example.invalid'] else 'reflection_b'
        COUNTS[key] += 1
        return 200, []
    if owner == USERS['fixture-b@example.invalid']:
        COUNTS['flows_b'] += 1
        return 200, []
    COUNTS['flows_a'] += 1
    today = datetime.now(timezone.utc).date().isoformat()
    return 200, [{'id': 101, 'action_type': 'expense', 'amount': 1000,
                  'description': '吉野家 食事', 'occurred_at': today + 'T12:00:00Z'}]


class Handler(BaseHTTPRequestHandler):
    def _handle(self):
        raw_length = self.headers.get('content-length', '0')
        if (self.headers.get('transfer-encoding') or len(raw_length) > 6 or
                not raw_length.isascii() or not raw_length.isdecimal()):
            if self.command not in {'GET', 'OPTIONS'}:
                COUNTS['rejected_writes'] += 1
            self.send_error(400)
            return
        length = int(raw_length)
        if length > 1024:
            if self.command not in {'GET', 'OPTIONS'}:
                COUNTS['rejected_writes'] += 1
            self.send_error(413)
            return
        body = self.rfile.read(length)
        headers = {key.lower(): value for key, value in self.headers.items()}
        status, result = dispatch(self.command, self.path, headers, body)
        payload = b'' if result is None else json.dumps(result).encode()
        self.send_response(status)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers',
                         'authorization, apikey, x-client-info, content-type, accept, '
                         'accept-profile, content-profile, prefer, range, range-unit, '
                         'x-asset-flow-version, x-supabase-api-version')
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = _handle

    def __getattr__(self, name):
        if name.startswith('do_'):
            return self._handle
        raise AttributeError(name)

    def log_message(self, *_args):
        pass


def namespace_only_loopback():
    try:
        output = subprocess.run(['ip', '-j', 'link', 'show'], check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                timeout=5).stdout
        links = json.loads(output)
        return (isinstance(links, list) and len(links) == 1 and
                isinstance(links[0], dict) and links[0].get('ifname') == 'lo')
    except (OSError, subprocess.SubprocessError, ValueError, UnicodeDecodeError):
        return False


if __name__ == '__main__':
    if not namespace_only_loopback():
        raise SystemExit('refusing to start without loopback-only network namespace')
    HTTPServer(('127.0.0.1', 18765), Handler).serve_forever()
