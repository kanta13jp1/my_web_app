"""Real loopback HTTP disconnects against a disposable synthetic DB gateway.

The gateway is a test double, not PostgREST or the Flutter application.
Never point this script at a production database.
"""
import http.client
import json
import os
import re
import socket
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from http_transport_safety import validate_environment, validate_marker_count

OWNER = 'aaaaaaaa-0000-0000-0000-000000000001'
ACCOUNT = 'aaaaaaaa-1111-1111-1111-111111111111'


def psql(sql):
    result = subprocess.run(
        ['psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
         '-v', 'VERBOSITY=verbose', '-c', sql],
        capture_output=True, text=True, timeout=15,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr)
    return result.stdout


def scalar(sql):
    return psql(sql).strip().splitlines()[-1]


fixture_token = validate_environment(os.environ)
if scalar('select current_database()') != 'payroll_contract':
    raise RuntimeError('Refusing to use a non-fixture database')
validate_marker_count(scalar(
    f"select count(*) from public.payroll_transport_fixture_guard "
    f"where token='{fixture_token}'::uuid"))


def save(month, request, delay=0):
    request_id = f'00000000-0000-0000-0000-{request:012d}'
    out = psql(f"""begin;
      set application_name='payroll-http-transport-test';
      set role authenticated;
      select set_config('request.jwt.claim.sub', '{OWNER}', true);
      select public.confirm_payroll_balance_observation(
        '{ACCOUNT}', '2030-{month:02d}-01', 'synthetic-{request}',
        '2030-{month:02d}-20', 'day', null, null, {700 + request},
        'synthetic source', '{request_id}', null, 'synthetic reason', true);
      select pg_sleep({delay});
      commit;""")
    ids = [line for line in out.splitlines()
           if re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', line)
           and line != OWNER]
    assert len(ids) == 1, out
    return ids[0]


def counts(month):
    return scalar(f"""select
      (select count(*) from public.asset_payroll_balance_observations
       where payroll_month='2030-{month:02d}-01') || '|' ||
      (select count(*) from public.asset_payroll_balance_selections
       where payroll_month='2030-{month:02d}-01') || '|' ||
      (select count(*) from public.asset_payroll_balance_selection_history
       where payroll_month='2030-{month:02d}-01')""")


started = threading.Event()
finished = threading.Event()
transport_failed = threading.Event()
state = {}


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        assert json.loads(self.rfile.read(length)) == {'fixture': 'synthetic'}
        if self.path == '/lost-after-commit':
            state['after_id'] = save(6, 50)
            self.close_connection = True
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
            return
        if self.path == '/lost-in-flight':
            started.set()
            state['inflight_id'] = save(7, 60, 4)
            try:
                self._respond(state['inflight_id'])
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                transport_failed.set()
            finally:
                finished.set()
            return
        if self.path == '/retry-after-commit':
            self._respond(save(6, 50))
            return
        if self.path == '/retry-in-flight':
            self._respond(save(7, 60))
            return
        raise AssertionError('unexpected fixture route')

    def _respond(self, record_id):
        payload = json.dumps({'id': record_id}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
        self.wfile.flush()


server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
host, port = server.server_address


def request(route):
    conn = http.client.HTTPConnection(host, port, timeout=10)
    conn.request('POST', route, body=json.dumps({'fixture': 'synthetic'}),
                 headers={'Content-Type': 'application/json'})
    return conn


try:
    # Server committed but closes TCP before sending any response.
    conn = request('/lost-after-commit')
    try:
        conn.getresponse()
        raise AssertionError('expected actual lost HTTP response')
    except http.client.RemoteDisconnected:
        pass
    finally:
        conn.close()
    assert counts(6) == '1|1|1', counts(6)
    conn = request('/retry-after-commit')
    response = conn.getresponse()
    assert response.status == 200
    assert json.loads(response.read())['id'] == state['after_id']
    conn.close()
    assert counts(6) == '1|1|1', counts(6)
    print('PASS: TCP response lost after commit; exact retry returns same id')

    # Reset the HTTP client while the SQL transaction is visibly still open.
    conn = request('/lost-in-flight')
    assert started.wait(5), 'gateway did not start'
    for _ in range(60):
        waiting = scalar("""select count(*) from pg_stat_activity
          where application_name='payroll-http-transport-test'
            and wait_event='PgSleep'""")
        if waiting == '1':
            break
        time.sleep(0.05)
    else:
        raise AssertionError('in-flight database transaction was not observed')
    assert counts(7) == '0|0|0', counts(7)
    conn.sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
    conn.close()
    assert finished.wait(10), 'database transaction did not finish'
    assert transport_failed.is_set(), 'server did not observe disconnected client'
    assert counts(7) == '1|1|1', counts(7)
    conn = request('/retry-in-flight')
    response = conn.getresponse()
    assert response.status == 200
    assert json.loads(response.read())['id'] == state['inflight_id']
    conn.close()
    assert counts(7) == '1|1|1', counts(7)
    print('PASS: HTTP client reset before commit; server commits and retry stays idempotent')
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
