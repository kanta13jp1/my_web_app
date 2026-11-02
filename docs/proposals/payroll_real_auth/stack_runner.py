"""Synthetic Auth + Envoy + PostgREST fixture. Never use production credentials.

GitHub-hosted disposable service only; no host ports, binds, or real user data.
The Envoy routes are test-only, not the production gateway configuration.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import secrets
import subprocess
import tempfile
import threading
import time
import uuid

import stack_guard as guard

HERE = Path(__file__).resolve().parent
MIGRATION_SHA = '23641f86ff7534a209a2089adc5a0b47fdc70e031af72f6301cffd9ce92586ba'
FIXED = {'migration.sql': MIGRATION_SHA,
         'envoy-fixture.yaml': 'd88fa8007c405b34e37531ae708af964586bc4d6c1c1e1ffb0d83c7462b30977',
         'synthetic_client.py': 'a9161327ed9f3d58412dd49393730097f6cd30f03fa5b0964039d45045faddb3',
         'auth_gateway_client.py': '4b02928f082f921ddfb24e89fd2bc9909c043cf3c1a1c695f2e3b7c0a0b35733'}
DB = 'payroll_auth_fixture'
PATH_INSIDE = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'


class OwnerClientExited(RuntimeError):
    def __init__(self, code):
        self.exit_code = code if isinstance(code, int) else None
        super().__init__('Synthetic owner client ended before marker')


class FixtureSqlError(RuntimeError):
    def __init__(self, code):
        self.sqlstate = code if isinstance(code, str) and re.fullmatch(r'[0-9A-Z]{5}', code) else None
        super().__init__('Synthetic SQL failed')


EMPTY_CHECK = """\\set ON_ERROR_STOP on
select case when current_database()='payroll_auth_fixture' and current_user='postgres'
 and current_setting('server_version_num')::int between 170000 and 179999
 and not exists (select 1 from pg_catalog.pg_roles where rolname in ('anon','authenticated','authenticator'))
 and not exists (select 1 from pg_catalog.pg_namespace where nspname not in ('public','information_schema') and pg_catalog.left(nspname,3) <> 'pg_')
 and not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p','v','m','f','S'))
 and not exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_extension where extname <> 'plpgsql')
 then 'EMPTY_FIXTURE' else 'NOT_EMPTY' end;
"""


class Fixture:
    def __init__(self, env):
        self.db_id, self.run_label = guard.job_identity(env)
        self.token = str(uuid.uuid4())
        self.password = secrets.token_hex(20)
        self.jwt_secret = secrets.token_hex(32)
        self.name = 'payroll-auth-' + uuid.uuid4().hex
        self.network_id = None
        self.created = {}
        self.clients = []
        self.tmp = tempfile.TemporaryDirectory(prefix='synthetic-auth-')
        self.env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C'}
        self.docker = ['/usr/bin/docker', '--config', self.tmp.name,
                       '--host', 'unix:///var/run/docker.sock']
        self.stage = 'initial inspection'
        self.images = {}

    def cmd(self, *args, data=None, timeout=30):
        return subprocess.run(self.docker + list(args), input=data, capture_output=True,
                              text=True, env=self.env, timeout=timeout, check=True)

    def info(self, cid):
        return json.loads(self.cmd('inspect', cid).stdout)[0]

    def check_db(self, *, isolated):
        info = self.info(self.db_id)
        if not guard.container_ok(info, self.db_id, self.images['db'], guard.POSTGRES,
                                  self.run_label, db=True):
            raise RuntimeError('Job database container identity mismatch')
        if isolated and not guard.member_of_only(info, self.name, self.network_id):
            raise RuntimeError('Database is not exclusively on fixture network')
        return info

    def check_network(self):
        data = json.loads(self.cmd('network', 'inspect', self.network_id).stdout)[0]
        if not guard.network_ok(data, self.network_id, self.run_label):
            raise RuntimeError('Fixture network identity mismatch')

    def check_component(self, kind):
        cid = self.created[kind]
        info = self.info(cid)
        if not guard.container_ok(info, cid, self.images[kind], guard.IMAGES[kind], self.run_label):
            raise RuntimeError('Fixture component identity mismatch')
        if not guard.member_of_only(info, self.name, self.network_id):
            raise RuntimeError('Fixture component network mismatch')
        aliases = info['NetworkSettings']['Networks'][self.name].get('Aliases') or []
        if 'synthetic-' + kind not in aliases:
            raise RuntimeError('Fixture component alias mismatch')
        self.check_network()
        return cid

    def check_peers(self):
        self.check_network()
        info = json.loads(self.cmd('network', 'inspect', self.network_id).stdout)[0]
        if set((info.get('Containers') or {}).keys()) != {self.db_id, *self.created.values()}:
            raise RuntimeError('Unexpected fixture network peers')
        db = self.check_db(isolated=True)
        aliases = db['NetworkSettings']['Networks'][self.name].get('Aliases') or []
        if 'synthetic-db' not in aliases:
            raise RuntimeError('Fixture database alias mismatch')
        for kind in self.created:
            self.check_component(kind)

    def db_sql(self, sql, *, marker=True):
        self.check_db(isolated=True)
        self.check_network()
        if marker:
            sql = ("\\set ON_ERROR_STOP on\nselect 1 / ((count(*) = 1)::int) "
                   "from public.payroll_auth_fixture_guard where token=:'fixture_token'::uuid;\n" + sql)
        try:
            result = self.cmd('exec', '-i', '-u', 'postgres', self.db_id,
                '/usr/bin/env', '-i', 'PATH=' + PATH_INSIDE, '/usr/local/bin/psql',
                '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate',
                '-v', 'fixture_token=' + self.token,
                '-h', '/var/run/postgresql', '-U', 'postgres', '-d', DB, data=sql)
        except subprocess.CalledProcessError as error:
            # Only expose a syntactically valid SQLSTATE, never the raw SQL or rows.
            match = re.search(r'(?:ERROR|FATAL):\s*([0-9A-Z]{5})\b', error.stderr or '')
            raise FixtureSqlError(match.group(1) if match else None) from None
        return result.stdout

    def pull_images(self):
        # Images are obtained before the synthetic network and any test code.
        self.images['db'] = json.loads(self.cmd('image', 'inspect', guard.POSTGRES).stdout)[0]['Id']
        self.check_db(isolated=False)
        for kind, image in guard.IMAGES.items():
            self.cmd('pull', image, timeout=180)
            info = json.loads(self.cmd('image', 'inspect', image).stdout)[0]
            if not any(item.endswith('@' + image.split('@', 1)[1]) for item in info.get('RepoDigests', [])):
                raise RuntimeError('Pinned image digest mismatch')
            self.images[kind] = info['Id']

    def isolate_db(self):
        before = self.check_db(isolated=False)
        networks = (before.get('NetworkSettings') or {}).get('Networks') or {}
        if len(networks) != 1:
            raise RuntimeError('Unexpected initial service network')
        initial = next(iter(networks))
        if not re.fullmatch(r'github_network_[0-9a-f]+', initial):
            raise RuntimeError('Unrecognized GitHub service network')
        self.network_id = self.cmd('network', 'create', '--internal', '--label',
            'payroll.auth.run=' + self.run_label, self.name).stdout.strip()
        if not re.fullmatch(r'[0-9a-f]{64}', self.network_id):
            raise RuntimeError('Unexpected fixture network identifier')
        self.check_network()
        self.cmd('network', 'connect', '--alias', 'synthetic-db', self.network_id, self.db_id)
        self.cmd('network', 'disconnect', initial, self.db_id)
        self.check_db(isolated=True)

    def create_component(self, kind, *, env=None, extra=None, command=None):
        args = ['create', '--pull=never', '--network', self.name,
                '--network-alias', 'synthetic-' + kind,
                '--label', 'payroll.auth.run=' + self.run_label]
        for key, value in (env or {}).items():
            args.extend(['--env', key + '=' + value])
        args.extend(extra or [])
        args.append(guard.IMAGES[kind])
        args.extend(command or [])
        cid = self.cmd(*args).stdout.strip()
        if not re.fullmatch(r'[0-9a-f]{64}', cid):
            raise RuntimeError('Unexpected fixture component identifier')
        self.created[kind] = cid
        return cid

    def start_component(self, kind):
        self.cmd('start', self.created[kind])
        self.check_component(kind)

    def client_python(self, code, *, env=None, timeout=30):
        cid = self.check_component('client')
        args = ['exec', '-i']
        for key, value in (env or {}).items():
            args.extend(['--env', key + '=' + value])
        args += [cid, '/usr/local/bin/python', '-B', '-']
        return self.cmd(*args, data=code, timeout=timeout).stdout

    def start_owner_client(self, source):
        cid = self.check_component('client')
        self.cmd('exec', '-i', cid, '/bin/sh', '-c', 'cat > /tmp/synthetic_client.py', data=source)
        self.check_component('client')
        args = self.docker + ['exec', '-i', '--env', 'FIXTURE_JWT_SECRET=' + self.jwt_secret,
                              cid, '/usr/local/bin/python', '-B', '/tmp/synthetic_client.py']
        proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, env=self.env, bufsize=1)
        self.clients.append(proc)
        output = queue.Queue()
        def collect():
            for line in proc.stdout:
                output.put(line.rstrip())
            output.put(None)
        threading.Thread(target=collect, daemon=True).start()
        return proc, output

    @staticmethod
    def wait_marker(proc, output, expected, timeout=120):
        end = time.monotonic() + timeout
        while True:
            remaining = end - time.monotonic()
            if remaining <= 0:
                raise TimeoutError('Synthetic owner client marker missing')
            try:
                line = output.get(timeout=remaining)
                if line is None:
                    code = proc.poll()
                    if code is None:
                        try:
                            code = proc.wait(timeout=1)
                        except subprocess.TimeoutExpired:
                            pass
                    raise OwnerClientExited(code)
                if line == expected:
                    return
            except queue.Empty as error:
                raise TimeoutError('Synthetic owner client marker missing') from error

    def wait_http(self, url):
        # Internal service-name URLs are fixed in caller; no arbitrary host input.
        if url not in ('http://synthetic-auth:9999/health', 'http://synthetic-gateway:8000/auth/v1/health'):
            raise RuntimeError('Unexpected readiness URL')
        program = "import urllib.request\nwith urllib.request.urlopen(" + repr(url) + ",timeout=2) as r:\n print(r.status)\n"
        end = time.monotonic() + 60
        while time.monotonic() < end:
            try:
                if self.client_python(program).strip() == '200': return
            except subprocess.CalledProcessError:
                pass
            time.sleep(.5)
        raise TimeoutError('Synthetic service readiness failed')

    def check_egress(self):
        # Negative probes use reserved TEST-NET and link-local metadata only.
        # They do not prove the absence of every host/DNS forwarding path.
        program = """import socket
for ip,port in [('192.0.2.1',443),('2001:db8::1',443),('169.254.169.254',80)]:
    try:
        conn=socket.create_connection((ip,port),timeout=1)
    except OSError:
        continue
    conn.close()
    raise SystemExit('unexpected external connection')
print('BLOCKED')
"""
        if self.client_python(program).strip() != 'BLOCKED':
            raise RuntimeError('Synthetic client egress check failed')

    def snapshot(self):
        # Only synthetic rows exist in this isolated database; never print them.
        query = """select jsonb_build_object(
          'accounts',(select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.asset_payroll_accounts t),
          'observations',(select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.asset_payroll_balance_observations t),
          'selections',(select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.asset_payroll_balance_selections t),
          'history',(select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.asset_payroll_balance_selection_history t)
        )::text;"""
        value = json.loads(self.db_sql(query).strip().splitlines()[-1])
        if not all(isinstance(value.get(key), list) and len(value[key]) == 2
                   for key in ('accounts', 'observations', 'selections', 'history')):
            raise RuntimeError('Synthetic owner positive rows missing')
        return value

    def rest_outage_check(self):
        before = self.snapshot()
        rest = self.check_component('rest')
        self.cmd('stop', '--time', '5', rest)
        probe = """import http.client
c=http.client.HTTPConnection('synthetic-gateway',8000,timeout=5)
c.request('GET','/rest/v1/asset_payroll_accounts')
r=c.getresponse()
if r.status != 503: raise SystemExit('unexpected outage status')
r.read()
print('OUTAGE_OBSERVED')
"""
        if self.client_python(probe).strip() != 'OUTAGE_OBSERVED':
            raise RuntimeError('Gateway did not expose expected backend outage')
        self.start_component('rest')
        ready = """import http.client, json
c=http.client.HTTPConnection('synthetic-gateway',8000,timeout=5)
c.request('GET','/rest/v1/asset_payroll_accounts')
r=c.getresponse(); value=json.loads(r.read())
if r.status not in (401,403) or value.get('code') != '42501':
 raise SystemExit('unexpected restored anonymous response')
print('RESTORED')
"""
        end = time.monotonic() + 40
        while time.monotonic() < end:
            try:
                if self.client_python(ready).strip() == 'RESTORED':
                    break
            except subprocess.CalledProcessError:
                pass
            time.sleep(.5)
        else:
            raise TimeoutError('Synthetic PostgREST did not recover')
        if self.snapshot() != before:
            raise RuntimeError('Synthetic rows changed during read-only outage')

    def execute(self, migration, client_source, client_module, gateway_config):
        self.stage = 'pull pinned fixture images'
        self.pull_images()
        self.stage = 'isolate service database'
        self.isolate_db()
        if self.db_sql(EMPTY_CHECK, marker=False).strip() != 'EMPTY_FIXTURE':
            raise RuntimeError('Expected empty synthetic database')
        self.db_sql("\\set ON_ERROR_STOP on\ncreate table public.payroll_auth_fixture_guard(token uuid primary key);\n"
                    "insert into public.payroll_auth_fixture_guard values (:'fixture_token'::uuid);\n", marker=False)
        self.db_sql("create role anon nologin; create role authenticated nologin; "
                    "create role authenticator noinherit login password '" + self.password + "'; "
                    "grant anon, authenticated to authenticator; create schema auth;\n")
        self.stage = 'start synthetic client and Auth'
        self.create_component('client', command=['python', '-c', 'import time; time.sleep(600)'])
        self.start_component('client')
        self.check_egress()
        self.create_component('auth', env={
            'GOTRUE_API_HOST': '0.0.0.0', 'GOTRUE_API_PORT': '9999',
            'API_EXTERNAL_URL': 'http://synthetic-gateway:8000/auth/v1',
            'GOTRUE_DB_DRIVER': 'postgres',
            'GOTRUE_DB_DATABASE_URL': 'postgres://postgres:synthetic-only@synthetic-db:5432/' + DB,
            'GOTRUE_SITE_URL': 'http://synthetic-gateway:8000',
            'GOTRUE_DISABLE_SIGNUP': 'false', 'GOTRUE_JWT_ADMIN_ROLES': 'service_role',
            'GOTRUE_JWT_AUD': 'authenticated', 'GOTRUE_JWT_DEFAULT_GROUP_NAME': 'authenticated',
            'GOTRUE_JWT_EXP': '3600', 'GOTRUE_JWT_SECRET': self.jwt_secret,
            'GOTRUE_JWT_ISSUER': 'http://synthetic-gateway:8000/auth/v1',
            'GOTRUE_EXTERNAL_EMAIL_ENABLED': 'true', 'GOTRUE_MAILER_AUTOCONFIRM': 'true',
            'GOTRUE_EXTERNAL_PHONE_ENABLED': 'false', 'GOTRUE_SMTP_HOST': '127.0.0.1',
        })
        self.start_component('auth')
        self.wait_http('http://synthetic-auth:9999/health')
        self.stage = 'verify Auth-provided uid function'
        status = self.db_sql("select case when to_regprocedure('auth.uid()') is not null "
                             "then 'UID_PRESENT' else 'UID_MISSING' end;").strip().splitlines()[-1]
        if status != 'UID_PRESENT':
            raise RuntimeError('Auth-provided uid function missing')
        self.db_sql("grant usage on schema auth to anon,authenticated; "
                    "grant execute on function auth.uid() to anon,authenticated;\n")
        self.stage = 'apply fixed synthetic migration'
        self.db_sql(migration)
        self.stage = 'start synthetic PostgREST and Envoy'
        self.create_component('rest', env={
            'PGRST_DB_URI': 'postgres://authenticator:' + self.password + '@synthetic-db:5432/' + DB,
            'PGRST_DB_SCHEMAS': 'public', 'PGRST_DB_ANON_ROLE': 'anon',
            'PGRST_JWT_SECRET': self.jwt_secret, 'PGRST_DB_USE_LEGACY_GUCS': 'false',
        })
        self.start_component('rest')
        encoded = base64.b64encode(gateway_config.encode('utf-8')).decode('ascii')
        self.create_component('gateway', env={'SYNTHETIC_ENVOY_CONFIG_B64': encoded},
            extra=['--entrypoint', '/bin/sh'], command=['-c',
              'printf %s "$SYNTHETIC_ENVOY_CONFIG_B64" | base64 -d > /tmp/fixture.yaml && '
              'exec /usr/local/bin/envoy -c /tmp/fixture.yaml --log-level error'])
        self.start_component('gateway')
        self.wait_http('http://synthetic-gateway:8000/auth/v1/health')
        self.stage = 'synthetic isolated client checks'
        self.check_peers()
        # Client receives only a test secret and fixed service-name endpoint.
        client = self.check_component('client')
        self.cmd('exec', '-i', client, '/bin/sh', '-c', 'cat > /tmp/auth_gateway_client.py',
                 data=client_module)
        owner_client, output = self.start_owner_client(client_source)
        self.wait_marker(owner_client, output, 'SYNTHETIC_INITIAL_READY')
        self.stage = 'synthetic gateway upstream outage'
        self.rest_outage_check()
        self.stage = 'authenticated owner checks after recovery'
        self.check_peers()
        owner_client.stdin.write('SYNTHETIC_RESTORED\n')
        owner_client.stdin.flush()
        self.wait_marker(owner_client, output, 'SYNTHETIC_RECOVERY_VERIFIED')
        owner_client.stdin.close()
        if owner_client.wait(timeout=10) != 0:
            raise RuntimeError('Synthetic owner client did not exit cleanly')

    def close(self):
        # Only IDs returned by our own create calls are candidates for removal.
        errors = []
        for proc in self.clients:
            if proc.poll() is None:
                try:
                    proc.terminate()
                    proc.wait(timeout=5)
                except Exception:
                    errors.append('client process')
        for kind in reversed(list(self.created)):
            try:
                info = self.info(self.created[kind])
                if not guard.container_ok(info, self.created[kind], self.images[kind],
                                          guard.IMAGES[kind], self.run_label, require_running=False):
                    raise RuntimeError('Cleanup component identity mismatch')
                networks = (info.get('NetworkSettings') or {}).get('Networks') or {}
                if networks and (set(networks) != {self.name}
                    or networks[self.name].get('NetworkID') != self.network_id):
                    raise RuntimeError('Cleanup component network mismatch')
                self.cmd('rm', '-f', self.created[kind])
            except Exception:
                errors.append(kind)
        if self.network_id:
            try:
                self.check_network()
                info = self.check_db(isolated=False)
                networks = (info.get('NetworkSettings') or {}).get('Networks') or {}
                if self.name in networks:
                    if networks[self.name].get('NetworkID') != self.network_id:
                        raise RuntimeError('Cleanup database network mismatch')
                    self.cmd('network', 'disconnect', self.network_id, self.db_id)
                self.cmd('network', 'rm', self.network_id)
            except Exception:
                errors.append('network')
        self.tmp.cleanup()
        if errors:
            raise RuntimeError('Fixture cleanup incomplete: ' + ', '.join(errors))


def main():
    fixed = {}
    for name, expected in FIXED.items():
        raw = (HERE / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise RuntimeError('Fixed fixture hash mismatch: ' + name)
        fixed[name] = raw.decode('utf-8')
    fixture = Fixture(os.environ)
    try:
        fixture.execute(fixed['migration.sql'], fixed['synthetic_client.py'],
                        fixed['auth_gateway_client.py'], fixed['envoy-fixture.yaml'])
        print('Synthetic real Auth + test Envoy + PostgREST checks passed.')
    except FixtureSqlError as error:
        print('Synthetic fixture failed at stage:', fixture.stage,
              'SQLSTATE:', error.sqlstate or 'unavailable')
        raise SystemExit(1) from None
    except OwnerClientExited as error:
        print('Synthetic fixture failed at stage:', fixture.stage,
              'owner client exited before marker; exit code:', error.exit_code)
        raise SystemExit(1) from None
    except Exception as error:
        print('Synthetic fixture failed at stage:', fixture.stage, type(error).__name__)
        raise SystemExit(1) from None
    finally:
        fixture.close()


if __name__ == '__main__':
    main()
