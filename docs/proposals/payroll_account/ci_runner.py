"""Synthetic account test in one GitHub Actions PostgreSQL service only.

This does not test Supabase Auth, Kong, Envoy, the real app or real user data.
No caller-provided host, DSN, database name, credentials or SQL is accepted.
"""
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import tempfile
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
IMAGE = 'postgres@sha256:e4cb93687b062cd25a0e8f672d85a7708235009d70d31f8a7698d9370092a9c4'
DB = 'payroll_contract'
FIXED = {
    'migration.sql': '23641f86ff7534a209a2089adc5a0b47fdc70e031af72f6301cffd9ce92586ba',
    'rpc.sql.disabled': '4b20ceccfc88a955f689ab2cc4c208470b892a986afd94ecf815cbd5db5a3314',
    'acl.sql.disabled': '26538f5f0da7b18a15f5d0f40e7e4f7b11336199808de7a8deabb9b767471c45',
    'legacy-before.sql.disabled': 'd8b73789c2683929e7aed72250b29511290e788547ae12d22a9640c43fc9d826',
    'legacy-after.sql.disabled': 'b72ba3fd191e4e44f18bee8333829d3e218bf9e08f9c23894f6b73172a76c67a',
    'seed-existing.sql.disabled': 'c8ded2813f65f8619d33851b187ef558c2052e33a0c8192d4cbefd9ee64a9b1f',
    'session-a.sql.disabled': '1d40d55c182aa67a26b4a7bdccb1327b9b10edd901856716d2e60b9176868f21',
    'session-b.sql.disabled': 'c60b32763a1535f8230d3fe551775ef74a20d7594c77ebc76d58eeea7cb78fb5',
    'verify-after.sql.disabled': '5486506b3d5bdd01234694b44d9ad5102b4d781c959a4b6372bbe902605bd84a',
    'verify-existing.sql.disabled': '5b601b6ee3e439656b1e41d2d3bdcacf0545ea64da90d7cb80cba10a8f4468da',
}
RPC_STOP = "do $review_only$ begin\n  raise exception 'REVIEW ONLY: draft DDL execution is prohibited';\nend $review_only$;"
ACL_STOP = "do $stop$ begin\n  raise exception 'REVIEW ONLY: ACL candidate execution is prohibited';\nend $stop$;"
TEST_STOP = "do $stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $stop$;"
PRELUDE = r"""\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
"""


def load_sources():
    result = {}
    for name, expected in FIXED.items():
        raw = (HERE / 'sql' / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise RuntimeError('Fixed SQL hash mismatch: ' + name)
        text = raw.decode('utf-8').replace('\r\n', '\n')
        stop = (RPC_STOP if name.startswith('rpc.') else ACL_STOP if name.startswith('acl.')
                else None if name == 'migration.sql' else TEST_STOP)
        if stop is not None:
            if text.count(stop) != 1:
                raise RuntimeError('Review stop missing or repeated: ' + name)
            text = text.replace(stop, '', 1)
        result[name] = text
    return result


def validate_ci_environment(env):
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    if (env.get('GITHUB_ACTIONS') != 'true' or not __debug__
        or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != 'kanta13jp1/my_web_app'
        or env.get('GITHUB_JOB') != 'synthetic-postgres'
        or env.get('GITHUB_EVENT_NAME') not in ('pull_request', 'workflow_dispatch')
        or not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9]+', attempt)):
        raise RuntimeError('Expected GitHub-hosted synthetic job identity')
    return run + '-' + attempt


def container_ok(info, identifier, image_id, run_label):
    config, host = info.get('Config') or {}, info.get('HostConfig') or {}
    if (info.get('Id') != identifier or info.get('Image') != image_id
        or not info.get('State', {}).get('Running') or config.get('Image') != IMAGE
        or (config.get('Labels') or {}).get('payroll.synthetic.run') != run_label
        or not {'POSTGRES_DB=payroll_contract', 'POSTGRES_PASSWORD=synthetic-account-only'}.issubset(
            set(config.get('Env') or []))
        or host.get('Privileged') or host.get('Binds') or host.get('PortBindings')
        or host.get('NetworkMode') == 'host'):
        return False
    if set((host.get('Tmpfs') or {}).keys()) != {'/var/lib/postgresql/data'}:
        return False
    return all(m.get('Type') == 'tmpfs' and
               m.get('Destination') == '/var/lib/postgresql/data'
               for m in (info.get('Mounts') or []))


class Service:
    def __init__(self, env):
        self.run_label = validate_ci_environment(env)
        self.cid = env.get('FIXTURE_CONTAINER_ID', '')
        if not re.fullmatch(r'[0-9a-f]{64}', self.cid):
            raise RuntimeError('Missing exact service container ID')
        self.marker = str(uuid.uuid4())
        self.config = tempfile.TemporaryDirectory(prefix='payroll-ci-docker-')
        self.env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C'}
        self.docker = ['/usr/bin/docker', '--config', self.config.name,
                       '--host', 'unix:///var/run/docker.sock']
        self.clients = []
        image_info = json.loads(self.cmd('image', 'inspect', IMAGE).stdout)[0]
        if IMAGE not in (image_info.get('RepoDigests') or []):
            raise RuntimeError('Service image digest not present')
        self.image_id = image_info['Id']
        self.inspect()

    def cmd(self, *args):
        return subprocess.run(self.docker + list(args), capture_output=True,
                              text=True, env=self.env, check=True, timeout=15)

    def inspect(self):
        info = json.loads(self.cmd('inspect', self.cid).stdout)[0]
        if not container_ok(info, self.cid, self.image_id, self.run_label):
            raise RuntimeError('Service container identity or isolation mismatch')

    def argv(self):
        self.inspect()
        return self.docker + ['exec', '-i', '-u', 'postgres', self.cid,
            '/usr/bin/env', '-i', 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
            '/usr/local/bin/psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
            '-v', 'fixture_token=' + self.marker, '-h', '/var/run/postgresql', '-U', 'postgres', '-d', DB]

    def sql(self, source, *, guard=True):
        if guard:
            source = ("\\set ON_ERROR_STOP on\nselect 1 / ((count(*) = 1)::int) "
                      "from public.payroll_transport_fixture_guard "
                      "where token = :'fixture_token'::uuid;\n" + source)
        return subprocess.run(self.argv(), input=source, capture_output=True,
                              text=True, env=self.env, check=True, timeout=30).stdout

    def async_sql(self, source):
        proc = subprocess.Popen(self.argv(), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, env=self.env, bufsize=1)
        self.clients.append(proc)
        output = queue.Queue()
        def collect():
            for line in proc.stdout:
                output.put(line.rstrip())
        threading.Thread(target=collect, daemon=True).start()
        proc.stdin.write(source + '\n')
        proc.stdin.flush()
        return proc, output

    @staticmethod
    def wait_for(output, expected):
        deadline = time.monotonic() + 20
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError('Synthetic session marker not observed')
            try:
                if output.get(timeout=left) == expected:
                    return
            except queue.Empty as error:
                raise TimeoutError('Synthetic session marker not observed') from error

    def close(self):
        for proc in self.clients:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)
        self.config.cleanup()


EMPTY_DATABASE_CHECK = """\\set ON_ERROR_STOP on
select case when current_database()='payroll_contract' and current_user='postgres'
  and current_setting('server_version_num')::int between 170000 and 179999
  and not exists (select 1 from pg_catalog.pg_roles where rolname in ('anon','authenticated'))
  and not exists (select 1 from pg_catalog.pg_namespace
                  where nspname not in ('public','information_schema') and pg_catalog.left(nspname,3) <> 'pg_')
  and not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
                  where n.nspname='public' and c.relkind in ('r','p','v','m','f','S'))
  and not exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public')
  and not exists (select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace
                  where n.nspname='public')
  and not exists (select 1 from pg_catalog.pg_extension where extname <> 'plpgsql')
  then 'EMPTY_FIXTURE' else 'NOT_EMPTY' end;
"""


def execute(service, s):
    if service.sql(EMPTY_DATABASE_CHECK, guard=False).strip() != 'EMPTY_FIXTURE':
        raise RuntimeError('Expected empty synthetic service database')
    service.sql("\\set ON_ERROR_STOP on\ncreate table public.payroll_transport_fixture_guard (token uuid primary key);\n"
                "insert into public.payroll_transport_fixture_guard values (:'fixture_token'::uuid);\n", guard=False)
    service.sql(PRELUDE)
    for name in ('migration.sql', 'seed-existing.sql.disabled', 'verify-existing.sql.disabled',
                 'legacy-before.sql.disabled', 'rpc.sql.disabled', 'acl.sql.disabled',
                 'legacy-after.sql.disabled', 'verify-existing.sql.disabled'):
        service.sql(s[name])
    marker = "\\prompt 'synthetic-only gate: ' release_gate"
    if s['session-a.sql.disabled'].count(marker) != 1:
        raise RuntimeError('Session gate missing or ambiguous')
    before, after = s['session-a.sql.disabled'].split(marker)
    a, qa = service.async_sql(before)
    service.wait_for(qa, 'SYNTHETIC_A_WAITING_WITH_UNCOMMITTED_ROW')
    b, qb = service.async_sql(s['session-b.sql.disabled'])
    check = """select case when exists (
      select 1 from pg_catalog.pg_stat_activity b
      join pg_catalog.pg_stat_activity a on a.pid = any(pg_catalog.pg_blocking_pids(b.pid))
      where a.application_name='synthetic_payroll_account_a'
        and b.application_name='synthetic_payroll_account_b' and b.wait_event_type='Lock'
      ) then 'BLOCKED' else 'NOT_BLOCKED' end;"""
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if b.poll() is not None:
            raise RuntimeError('Second session ended without observed lock')
        if service.sql(check).strip().splitlines()[-1] == 'BLOCKED':
            break
        time.sleep(.2)
    else:
        raise TimeoutError('Second session was not observed blocked')
    a.stdin.write(after + '\n')
    a.stdin.flush()
    service.wait_for(qa, 'SYNTHETIC_A_COMMITTED')
    a.stdin.close()
    if a.wait(timeout=10) != 0:
        raise RuntimeError('First transaction failed')
    service.wait_for(qb, 'SYNTHETIC_B_SAW_40001')
    b.stdin.close()
    if b.wait(timeout=10) != 0:
        raise RuntimeError('Second transaction failed')
    service.sql(s['verify-after.sql.disabled'])
    service.sql(s['verify-existing.sql.disabled'])


def main():
    sources = load_sources()
    service = Service(os.environ)
    try:
        execute(service, sources)
        print('Synthetic PostgreSQL two-session and preservation checks passed.')
    finally:
        service.close()


if __name__ == '__main__':
    main()
