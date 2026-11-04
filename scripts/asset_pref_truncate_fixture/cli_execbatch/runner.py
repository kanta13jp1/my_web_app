"""UNEXECUTED REVIEW DRAFT: actual Supabase CLI, disposable PG17 only.

No CLI entrypoint; a separately reviewed, hash-pinned orchestrator must call
run_matrix(). No network download, existing container, remote DB, linked
project, inherited credentials or production migration is accepted.
"""
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile
import time
from datetime import datetime, timezone
import uuid

HERE = Path(__file__).resolve().parent
ARCHIVE = HERE / 'supabase_linux_amd64.tar.gz'
ARCHIVE_SHA = '620a5f6ea7b60f9b4fe112a5d72464ea0e53d04022035641674a2e6d121e0eb5'
IMAGE = 'postgres@sha256:0b81cec82228160abfa753aeaad0609b709eb26eeb950f2e404ad2326e1cc370'
DB = 'synthetic_execbatch'
DB_URL = ('postgresql://postgres@/synthetic_execbatch?host=%2Fvar%2Frun%2Fpostgresql'
          '&sslmode=disable&application_name=codex_execbatch_cli')
SERVER_CMD = ['postgres', '-c', 'log_connections=on', '-c', 'log_error_verbosity=verbose']
STOP = b"\\set ON_ERROR_STOP on\ndo $review_stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $review_stop$;\n"
CANDIDATES = {
 'explicit': ('candidate_lock_rc_guard_review_stopped.sql.txt', '0c6f44d00885dc939355e22bd4860339662a31eb7e51ca1f6ef981ab81e51621'),
 'batch': ('candidate_lock_rc_cli_batch_review_stopped.sql.txt', 'e522e693c83dbc517ba26345546fdd06f0c02bb032ead12c124444227bf60a79'),
 'pr_head_06505ee4': ('revoke_truncate_candidate_review_stopped.sql.txt', '3372910f839d556a35d81dfd6ababe8c73438e52636d7fe8c491835528f1dfb6'),
}
VERSION = '20991231000000'
MIGRATION = '/tmp/codex-cli/supabase/migrations/20991231000000_synthetic_acl.sql'
FIXTURE_PASSWORD = 'synthetic-isolated-only'
MAX_BINARY = 150 * 1024 * 1024


def sha(data): return hashlib.sha256(data).hexdigest()


def job_identity(env):
    branch = 'refs/heads/codex/asset-pref-cli-execbatch-diagnostic-20261104'
    workflow_ref = 'kanta13jp1/my_web_app/.github/workflows/cloud-development.yml@' + branch
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    head, expected = env.get('GITHUB_SHA', ''), env.get('SYNTHETIC_EXPECTED_HEAD', '')
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != 'kanta13jp1/my_web_app'
        or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch' or env.get('GITHUB_JOB') != 'cli-execbatch-isolated'
        or env.get('GITHUB_REF') != branch or env.get('GITHUB_WORKFLOW_REF') != workflow_ref
        or not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9]+', attempt)
        or not re.fullmatch(r'[0-9a-f]{40}', head) or head != expected):
        raise RuntimeError('untrusted synthetic workflow identity')
    return run + '-' + attempt




def sibling(name):
    p = HERE / name
    if p.is_symlink() or not p.is_file() or p.resolve().parent != HERE:
        raise RuntimeError('invalid sibling: ' + name)
    return p


def safe_cli_binary():
    """Verify official compressed bytes and copy only a bounded regular binary.

    Nothing is extracted by path. Links, traversal, duplicates, devices and
    oversized members are rejected; the caller transfers the returned bytes.
    """
    archive = sibling(ARCHIVE.name)
    if archive.stat().st_size > 64 * 1024 * 1024:
        raise RuntimeError('official CLI archive size mismatch')
    data = archive.read_bytes()
    if sha(data) != ARCHIVE_SHA:
        raise RuntimeError('official CLI archive digest mismatch')
    return extract_binary_from_verified_archive(data)


def extract_binary_from_verified_archive(data):
    # Caller must verify the official archive SHA before this pure parser.
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tf:
        members = tf.getmembers()
        if len(members) > 32: raise RuntimeError('unexpected archive member count')
        seen = set(); binary = None
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not path.parts or '\\' in member.name:
                raise RuntimeError('unsafe archive path')
            normalized = str(path)
            if normalized in seen: raise RuntimeError('duplicate archive member')
            seen.add(normalized)
            if member.isdir(): continue
            if not member.isfile() or member.issym() or member.islnk() or member.size > MAX_BINARY:
                raise RuntimeError('unsafe archive member type or size')
            if normalized == 'supabase':
                if binary is not None or member.size <= 0: raise RuntimeError('ambiguous CLI binary')
                stream = tf.extractfile(member)
                if stream is None: raise RuntimeError('CLI member unreadable')
                binary = stream.read(MAX_BINARY + 1)
                if len(binary) != member.size or len(binary) > MAX_BINARY:
                    raise RuntimeError('CLI member size mismatch')
        if binary is None: raise RuntimeError('official archive has no root CLI binary')
        if len(binary) < 20 or binary[:6] != b'\x7fELF\x02\x01' or int.from_bytes(binary[18:20], 'little') != 62:
            raise RuntimeError('CLI binary is not little-endian ELF64 x86-64')
        return binary


def candidate_pair():
    decoded = {}
    for mode, (name, digest) in CANDIDATES.items():
        data = sibling(name).read_bytes()
        if sha(data) != digest or not data.startswith(STOP) or data.count(STOP) != 1:
            raise RuntimeError('candidate STOP/digest mismatch: ' + mode)
        decoded[mode] = data[len(STOP):]
    explicit = decoded['explicit'].replace(b'\r\n', b'\n')
    batch = decoded['batch'].replace(b'\r\n', b'\n')
    if explicit.count(b'\nbegin;\n') != 1 or explicit.count(b'\ncommit;') != 1 or not explicit.endswith(b'\ncommit;'):
        raise RuntimeError('unexpected explicit transaction boundaries')
    without_boundaries = explicit.replace(b'\nbegin;\n', b'\n', 1).removesuffix(b'\ncommit;') + b'\n'
    if without_boundaries != batch:
        raise RuntimeError('candidates differ beyond transaction boundaries')
    return decoded


def parse_tmp_mountinfo(text):
    matches = []
    for line in text.splitlines():
        if ' - ' not in line: continue
        before, after = line.split(' - ', 1)
        left, right = before.split(), after.split()
        if len(left) >= 6 and len(right) >= 3 and left[4] == '/tmp':
            matches.append((set(left[5].split(',')), right[0], set(right[2].split(','))))
    if len(matches) != 1:
        raise RuntimeError('actual /tmp mount not uniquely identified')
    flags, fs_type, super_flags = matches[0]
    if fs_type != 'tmpfs' or not {'rw','nosuid','nodev'} <= flags or 'noexec' in flags or 'noexec' in super_flags:
        raise RuntimeError('actual /tmp mount is not executable nosuid/nodev tmpfs')
    return {'filesystem': fs_type, 'mount_options': sorted(flags), 'super_options': sorted(super_flags)}


def verify_removed(cid, inspect_code, inspect_stdout, inspect_stderr, ps_code, ps_stdout, ps_stderr):
    if not re.fullmatch(r'[0-9a-f]{64}', cid): raise RuntimeError('invalid removed container ID')
    exact = {f'error: no such object: {cid}', f'error: no such container: {cid}',
             f'error response from daemon: no such object: {cid}',
             f'error response from daemon: no such container: {cid}'}
    if (inspect_code != 1 or inspect_stdout.strip() not in ('','[]')
        or inspect_stderr.strip().casefold() not in exact
        or ps_code != 0 or ps_stdout.strip() != '' or ps_stderr.strip() != ''):
        raise RuntimeError('owned container removal unconfirmed; inspect/ps evidence ambiguous')
    return True


STARTUP_MARKER = 'PostgreSQL init process complete; ready for start up.'
READINESS_SQL = r"""SELECT current_database(), current_user,
 current_setting('server_version_num')::int/10000, inet_client_addr() IS NULL,
 inet_server_addr() IS NULL, NOT pg_is_in_recovery(), pg_postmaster_start_time(),
 split_part(pg_catalog.pg_read_file('postmaster.pid',0,128), E'\n', 1);"""


def classify_psql_stderr(raw):
    if not isinstance(raw, bytes): raw = str(raw or '').encode('utf-8', errors='replace')
    text = raw.decode('utf-8', errors='replace').lower()
    patterns = (
        ('authentication', ('authentication failed','no pg_hba.conf entry','password authentication')),
        ('database_missing', ('database "synthetic_execbatch" does not exist',)),
        ('role_missing', ('role "postgres" does not exist',)),
        ('socket_unavailable', ('no such file or directory','connection refused','could not connect')),
        ('server_starting', ('starting up','shutting down','not yet accepting connections')),
        ('permission_denied', ('permission denied',)),
    )
    found = [label for label, terms in patterns if any(term in text for term in terms)]
    return {'categories':found or ['unclassified'], 'bytes':len(raw), 'sha256':sha(raw)}


def classify_failure(exc):
    raw = str(exc).encode('utf-8', errors='replace')
    text = raw.decode('utf-8', errors='replace').lower()
    patterns = (
        ('postmaster_changed', ('postmaster changed',)),
        ('identity_mismatch', ('identity, socket, recovery or postmaster check failed',)),
        ('startup_marker', ('initialization marker',)),
        ('readiness_deadline', ('readiness deadline',)),
        ('pg_isready_error', ('unexpected pg_isready',)),
        ('startup_postgres_fatal', ('fatal postgres log observed',)),
        ('psql_error', ('synthetic psql failed',)),
        ('container_identity', ('container identity', 'service identity')),
    )
    found = [label for label,terms in patterns if any(term in text for term in terms)]
    return {'categories':found or ['unclassified'], 'bytes':len(raw), 'sha256':sha(raw)}


def summarize_server_logs(text):
    encoded = text.encode('utf-8', errors='replace')
    fatal = [line for line in text.splitlines() if re.search(r'\b(?:FATAL|PANIC):', line)]
    categories = sorted({category for line in fatal
        for category in classify_psql_stderr(line.encode('utf-8', errors='replace'))['categories']})
    return {'startup_marker_count':text.count(STARTUP_MARKER),
            'ready_log_count':text.count('database system is ready to accept connections'),
            'shutdown_log_count':text.count('database system is shut down'),
            'fatal_line_count':len(fatal), 'fatal_categories':categories,
            'bytes':len(encoded), 'sha256':sha(encoded)}


def require_clean_final_logs(text):
    if summarize_server_logs(text)['fatal_line_count']:
        raise RuntimeError('fatal postgres log observed during startup')
    if text.count(STARTUP_MARKER) != 1:
        raise RuntimeError('final image initialization marker no longer uniquely present')


def validate_ready_state(output):
    fields = output.strip().split('|')
    if (len(fields) != 8 or fields[:6] != ['synthetic_execbatch','postgres','17','t','t','t']
        or not fields[6] or not re.fullmatch(r'[1-9][0-9]*', fields[7])):
        raise RuntimeError('synthetic database identity, socket, recovery or postmaster check failed')
    return {'database':fields[0], 'user':fields[1], 'pg_major':17,
            'unix_socket':True, 'not_in_recovery':True, 'postmaster_started':fields[6], 'postmaster_pid':fields[7]}


class FixturePsqlError(RuntimeError):
    def __init__(self, returncode, stderr):
        self.evidence = {'returncode':returncode, 'stderr':classify_psql_stderr(stderr)}
        super().__init__('synthetic psql failed: ' + json.dumps(self.evidence, sort_keys=True))


class OwnedService:
    """Only self-created, separately inspected, isolated Docker ID may be used."""
    def __init__(self, docker, env, image_info, run_id):
        if not re.fullmatch(r'[0-9]+-[0-9]+', run_id): raise RuntimeError('invalid synthetic run ID')
        self.docker, self.env, self.image_info, self.run_id = docker, env, image_info, run_id
        self.nonce = uuid.uuid4().hex
        self.token = str(uuid.uuid4())
        self.cid = None
        self.verified = False
        self.cli_binary_sha = None

    def command(self, args, *, input=None, timeout=30, check=True):
        return subprocess.run(self.docker + args, env=self.env, input=input,
            capture_output=True, check=check, timeout=timeout)

    def create(self):
        if IMAGE not in (self.image_info.get('RepoDigests') or []):
            raise RuntimeError('pinned local image digest missing; no pull performed')
        print('SYNTHETIC_EXECBATCH_CREATE_INTENT ' + json.dumps({'run_id':self.run_id, 'nonce':self.nonce,
            'utc':datetime.now(timezone.utc).isoformat(), 'image':IMAGE}, sort_keys=True), flush=True)
        cmd = ['create', '--network', 'none', '--ipc', 'private',
            '--label', 'codex.execbatch.owner=' + self.nonce,
            '--label', 'codex.execbatch.run=' + self.run_id,
            '--label', 'codex.execbatch.scope=synthetic',
            '--tmpfs', '/var/lib/postgresql/data:rw,nosuid,size=256m',
            '--tmpfs', '/tmp:rw,nosuid,nodev,exec,size=192m,mode=1777',
            '-e', 'POSTGRES_DB=' + DB, '-e', 'POSTGRES_PASSWORD=' + FIXTURE_PASSWORD, IMAGE] + SERVER_CMD
        result = self.command(cmd, timeout=30)
        cid = result.stdout.decode('ascii').strip()
        if not re.fullmatch(r'[0-9a-f]{64}', cid):
            raise RuntimeError('invalid returned container ID; do not stop any container')
        self.cid = cid
        self.inspect()  # if this fails, do not operate on an unverified ID
        self.verified = True
        self.command(['start', self.cid], timeout=30)
        self.inspect(running=True)

    def inspect(self, *, running=None):
        if not self.cid or not re.fullmatch(r'[0-9a-f]{64}', self.cid):
            raise RuntimeError('invalid owned container ID')
        info = json.loads(self.command(['inspect', self.cid]).stdout)[0]
        cfg, host, net, state = info['Config'], info['HostConfig'], info['NetworkSettings'], info['State']
        labels = cfg.get('Labels') or {}
        actual_env = {}
        for item in cfg.get('Env') or []:
            k, sep, v = item.partition('=')
            if not sep or k in actual_env: raise RuntimeError('container env malformed')
            actual_env[k] = v
        expected_env = {}
        for item in (self.image_info.get('Config') or {}).get('Env') or []:
            k, sep, v = item.partition('=')
            if not sep or k in expected_env: raise RuntimeError('image env malformed')
            expected_env[k] = v
        expected_env.update(POSTGRES_DB=DB, POSTGRES_PASSWORD=FIXTURE_PASSWORD)
        tmpfs = host.get('Tmpfs') or {}
        mounts = info.get('Mounts')
        if not isinstance(mounts, list): raise RuntimeError('mount inspection unavailable')
        allowed_mounts = {'/var/lib/postgresql/data', '/tmp'}
        options = {k: set((v or '').split(',')) for k, v in tmpfs.items()}
        image_cfg = self.image_info.get('Config') or {}
        valid = (
            info.get('Id') == self.cid and info.get('Image') == self.image_info.get('Id')
            and cfg.get('Image') == IMAGE and labels.get('codex.execbatch.owner') == self.nonce
            and labels.get('codex.execbatch.scope') == 'synthetic' and labels.get('codex.execbatch.run') == self.run_id
            and actual_env == expected_env
            and 'POSTGRES_INITDB_WALDIR' not in actual_env
            and cfg.get('Entrypoint') == image_cfg.get('Entrypoint') and cfg.get('Cmd') == SERVER_CMD
            and cfg.get('User', '') == image_cfg.get('User', '')
            and cfg.get('Tty') is False and cfg.get('OpenStdin') is False
            and host.get('NetworkMode') == 'none' and set((net.get('Networks') or {})) <= {'none'}
            and not any((net.get('Ports') or {}).values()) and not host.get('PortBindings')
            and host.get('PublishAllPorts') is False and host.get('Privileged') is False
            and host.get('IpcMode') in ('private', '') and host.get('PidMode') in ('', 'private')
            and host.get('UsernsMode') in ('', 'private')
            and not any(host.get(k) for k in ('Binds','CapAdd','Devices','DeviceRequests','ExtraHosts','Links','VolumesFrom','SecurityOpt'))
            and set(tmpfs) == allowed_mounts
            and {'rw','nosuid'} <= options['/var/lib/postgresql/data']
            and bool({'size=256m','size=268435456'} & options['/var/lib/postgresql/data'])
            and {'rw','nosuid','nodev','exec'} <= options['/tmp']
            and not ({'noexec','suid','dev'} & options['/tmp'])
            and bool({'size=192m','size=201326592'} & options['/tmp'])
            and bool({'mode=1777','mode=1023'} & options['/tmp'])
            and all(m.get('Type') == 'tmpfs' and m.get('Destination') in allowed_mounts for m in mounts)
            and isinstance(state.get('Running'), bool)
            and (running is None or state.get('Running') is running)
        )
        if not valid: raise RuntimeError('owned service identity/isolation mismatch; stop for manual review')
        return info

    def exec(self, args, *, input=None, timeout=30, check=True, workdir=None):
        self.inspect(running=True)
        cmd = ['exec', '-i', '-u', 'postgres']
        if workdir:
            if workdir != '/tmp/codex-cli': raise RuntimeError('unexpected container workdir')
            cmd += ['--workdir', workdir]
        cmd += [self.cid, '/usr/bin/env', '-i', 'PATH=/usr/local/bin:/usr/bin:/bin',
                'HOME=/tmp/codex-cli'] + args
        return self.command(cmd, input=input, timeout=timeout, check=check)

    def psql(self, sql, *, guarded=True):
        if not isinstance(sql, str): raise TypeError('fixed fixture SQL must be text')
        if guarded:
            if not re.fullmatch(r'[0-9a-f-]{36}', self.token): raise RuntimeError('invalid guard token')
            sql = ("SELECT 1 / ((current_database()='synthetic_execbatch' AND current_user='postgres' "
                "AND current_setting('server_version_num')::int/10000=17 AND EXISTS "
                "(SELECT 1 FROM public.codex_execbatch_guard WHERE token='" + self.token + "'::uuid))::int);\n" + sql)
        argv = ['/usr/lib/postgresql/17/bin/psql','-X','-qAt','-v','ON_ERROR_STOP=1',
                '-h','/var/run/postgresql','-U','postgres','-d',DB]
        result = self.exec(argv, input=sql.encode('utf-8'), timeout=20, check=False)
        if result.returncode != 0:
            raise FixturePsqlError(result.returncode, result.stderr)
        output = result.stdout.decode('utf-8')
        if guarded:
            lines = output.splitlines()
            if not lines or lines[0] != '1': raise RuntimeError('fixture guard not confirmed')
            return '\n'.join(lines[1:])
        return output.strip()

    def wait_final_postmaster(self):
        """Wait for the pinned image's final server; never retry psql errors."""
        deadline = time.monotonic() + 40
        while True:
            logs = self.logs()  # inspect identity; logs never emitted raw
            summary = summarize_server_logs(logs)
            if summary['fatal_line_count']:
                raise RuntimeError('fatal postgres log observed during startup')
            marker_count = logs.count(STARTUP_MARKER)
            if marker_count > 1:
                raise RuntimeError('unexpected repeated image initialization marker')
            if marker_count == 1:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('final image initialization marker not observed before deadline')
            time.sleep(0.5)
        while True:
            # Inspect fresh owned-container logs before every connection probe.
            # Never continue polling after a classified fatal auth/identity issue.
            require_clean_final_logs(self.logs())
            probe = self.exec(['/usr/bin/pg_isready','-h','/var/run/postgresql','-U','postgres',
                               '-d',DB,'-t','2'], timeout=5, check=False)
            if probe.returncode == 0:
                break
            if probe.returncode not in (1,2):
                raise RuntimeError('unexpected pg_isready failure: ' + str(probe.returncode))
            if time.monotonic() >= deadline:
                raise RuntimeError('final postgres readiness deadline exceeded')
            time.sleep(0.5)
        # A correct DB and role are not implied by pg_isready. Any psql or
        # identity error aborts immediately; no retry is attempted.
        require_clean_final_logs(self.logs())
        first = validate_ready_state(self.psql(READINESS_SQL, guarded=False))
        time.sleep(0.5)
        require_clean_final_logs(self.logs())
        second = validate_ready_state(self.psql(READINESS_SQL, guarded=False))
        require_clean_final_logs(self.logs())
        if first != second:
            raise RuntimeError('postmaster changed during final readiness confirmation')
        print('SYNTHETIC_EXECBATCH_READY ' + json.dumps({'run_id':self.run_id,'nonce':self.nonce,
            'container_id':self.cid,'entrypoint_marker':True,'state':second},sort_keys=True),flush=True)
        return second

    def initialize(self):
        empty = self.psql("SELECT current_database()='synthetic_execbatch' AND current_user='postgres' "
            "AND current_setting('server_version_num')::int/10000=17 "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname IN ('anon','authenticated','service_role')) "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname NOT IN ('public','information_schema') AND left(nspname,3)<>'pg_') "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public') "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type t JOIN pg_catalog.pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public') "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_extension WHERE extname<>'plpgsql') "
            "AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','f','S'));", guarded=False)
        if empty != 't': raise RuntimeError('database not empty synthetic PG17')
        self.psql("CREATE TABLE public.codex_execbatch_guard(token uuid PRIMARY KEY); INSERT INTO public.codex_execbatch_guard VALUES ('" + self.token + "'::uuid);", guarded=False)
        self.psql(FIXTURE_SQL)
        self.psql(HISTORY_GATE)
        result = self.psql("SELECT (SELECT count(*) FROM supabase_migrations.schema_migrations), "
            "pg_catalog.has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE'), "
            "pg_catalog.has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE');")
        if result.strip() != '0|t|t': raise RuntimeError('fixture baseline mismatch: ' + result)

    def verify_cli_binary(self):
        if not self.cli_binary_sha or not re.fullmatch(r'[0-9a-f]{64}', self.cli_binary_sha):
            raise RuntimeError('staged CLI hash unavailable')
        mount = parse_tmp_mountinfo(self.exec(['/bin/cat','/proc/self/mountinfo']).stdout.decode('utf-8'))
        uid = self.exec(['/usr/bin/id','-u']).stdout.decode('ascii').strip()
        gid = self.exec(['/usr/bin/id','-g']).stdout.decode('ascii').strip()
        details = self.exec(['/usr/bin/stat','-c','%u|%g|%a|%F|%h',
            '/tmp/codex-cli/supabase-cli']).stdout.decode('ascii').strip()
        if not uid.isdecimal() or not gid.isdecimal() or details != '|'.join((uid,gid,'700','regular file','1')):
            raise RuntimeError('staged CLI owner, mode, type or link count mismatch: ' + details)
        found = self.exec(['/usr/bin/sha256sum','/tmp/codex-cli/supabase-cli']).stdout.decode('ascii').split()[0]
        if found != self.cli_binary_sha:
            raise RuntimeError('staged CLI hash mismatch')
        evidence = {'run_id':self.run_id, 'nonce':self.nonce, 'mount':mount, 'uid':uid, 'gid':gid,
                    'mode':'700', 'type':'regular file', 'links':1, 'sha256':found}
        print('SYNTHETIC_EXECBATCH_EXECUTABLE ' + json.dumps(evidence,sort_keys=True), flush=True)
        return evidence

    def stage(self, binary, migration):
        self.psql('SELECT 1;')  # confirm database marker immediately before staging
        self.exec(['/bin/sh','-c','umask 077; mkdir -p /tmp/codex-cli/supabase/migrations; cat > /tmp/codex-cli/supabase/migrations/20991231000000_synthetic_acl.sql'], input=migration)
        self.exec(['/bin/sh','-c','umask 077; cat > /tmp/codex-cli/supabase/config.toml'],
                  input=b'project_id = "synthetic-execbatch"\n[db.migrations]\nenabled = true\n')
        self.exec(['/bin/sh','-c','umask 077; cat > /tmp/codex-cli/supabase-cli; chmod 700 /tmp/codex-cli/supabase-cli'], input=binary, timeout=60)
        for file, expected in ((MIGRATION, sha(migration)), ('/tmp/codex-cli/supabase-cli', sha(binary))):
            got = self.exec(['/usr/bin/sha256sum', file]).stdout.decode('ascii').split()[0]
            if got != expected: raise RuntimeError('container staged content hash mismatch')
        # Explicitly reject symlinks or additional migration/config entries.
        def check_project_tree():
            entries = self.exec(['/usr/bin/find','/tmp/codex-cli/supabase','-mindepth','1','-printf','%y %p\n']).stdout.decode('utf-8').splitlines()
            expected = {'d /tmp/codex-cli/supabase/migrations', 'f ' + MIGRATION,
                        'f /tmp/codex-cli/supabase/config.toml'}
            if set(entries) != expected or len(entries) != len(expected):
                raise RuntimeError('unexpected synthetic project content')
        check_project_tree()
        self.cli_binary_sha = sha(binary)
        self.verify_cli_binary()
        version = self.exec(['/tmp/codex-cli/supabase-cli','--version'], timeout=20, check=False, workdir='/tmp/codex-cli')
        if version.returncode != 0 or version.stdout.decode('utf-8').strip() != '2.84.2':
            raise RuntimeError('fixed CLI version not confirmed: ' + (version.stdout + version.stderr).decode('utf-8', errors='replace'))
        check_project_tree()

    def cli_push(self):
        self.psql('SELECT 1;')
        self.verify_cli_binary()
        # Socket-only URI and -i cleared environment; no linked ref or fallback.
        args = ['/tmp/codex-cli/supabase-cli','db','push','--db-url',DB_URL,
                '--include-all','--yes','--workdir','/tmp/codex-cli']
        return self.exec(args, timeout=60, check=False, workdir='/tmp/codex-cli')

    def logs(self):
        self.inspect()
        result = self.command(['logs', self.cid], check=True, timeout=15)
        return (result.stdout + result.stderr).decode('utf-8', errors='replace')

    def stop_owned(self):
        if not self.verified:
            raise RuntimeError('container was not verified; no stop attempted; manual inspection required: ' + str(self.cid))
        started = time.monotonic()
        info = self.inspect()
        if info['State']['Running']:
            self.command(['stop','--time','5',self.cid], timeout=20)
        self.inspect(running=False)
        self.command(['rm',self.cid], timeout=20)
        missing = self.command(['inspect',self.cid], timeout=15, check=False)
        listed = self.command(['ps','--all','--no-trunc','--filter','id='+self.cid,'--format','{{.ID}}'], timeout=15, check=False)
        verify_removed(self.cid, missing.returncode, missing.stdout.decode('utf-8',errors='replace'),
            missing.stderr.decode('utf-8',errors='replace'), listed.returncode,
            listed.stdout.decode('utf-8',errors='replace'), listed.stderr.decode('utf-8',errors='replace'))
        print('SYNTHETIC_EXECBATCH_TEARDOWN ' + json.dumps({'run_id':self.run_id,'nonce':self.nonce,
            'container_id':self.cid,'stopped_removed':True,'inspect_absent':True,'ps_absent':True,
            'seconds':time.monotonic()-started}, sort_keys=True), flush=True)


FIXTURE_SQL = r"""
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE public.asset_pref_mirror (user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,pref_key));
ALTER TABLE public.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
CREATE POLICY synthetic_policy ON public.asset_pref_mirror FOR ALL TO authenticated USING (true) WITH CHECK (true);
INSERT INTO public.asset_pref_mirror VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','synthetic','{"fixture":true}', now());
GRANT ALL PRIVILEGES ON public.asset_pref_mirror TO anon,authenticated,service_role;
CREATE SCHEMA supabase_migrations;
CREATE TABLE supabase_migrations.schema_migrations (version text NOT NULL PRIMARY KEY, statements text[], name text);
"""
HISTORY_GATE = r"""
CREATE TABLE public.codex_execbatch_mode(mode text NOT NULL CHECK (mode IN ('normal','fail')));
INSERT INTO public.codex_execbatch_mode VALUES ('normal');
CREATE FUNCTION supabase_migrations.synthetic_history_gate() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF current_database() <> 'synthetic_execbatch' OR current_user <> 'postgres'
    OR current_setting('server_version_num')::int/10000 <> 17
    OR inet_client_addr() IS NOT NULL OR inet_server_addr() IS NOT NULL
    OR (SELECT count(*) FROM public.codex_execbatch_guard) <> 1
    OR NEW.version <> '20991231000000' THEN
   RAISE EXCEPTION 'SYNTHETIC_ROUTE_OR_HISTORY_MISMATCH';
 END IF;
 IF (SELECT mode FROM public.codex_execbatch_mode) = 'fail' THEN
   RAISE EXCEPTION 'SYNTHETIC_HISTORY_FAILURE' USING ERRCODE='P0001';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER synthetic_history_gate BEFORE INSERT ON supabase_migrations.schema_migrations
FOR EACH ROW EXECUTE FUNCTION supabase_migrations.synthetic_history_gate();
"""
HISTORY_FAILURE = "UPDATE public.codex_execbatch_mode SET mode='fail';"
CHILD_FAILURE = 'CREATE TABLE public.synthetic_child () INHERITS (public.asset_pref_mirror);'

SNAPSHOT = r"""SELECT jsonb_build_object(
 'owner',c.relowner,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,'acl',c.relacl::text,
 'rows',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.user_id,t.pref_key),'[]') FROM ONLY public.asset_pref_mirror t),
 'policy',(SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.policyname),'[]') FROM pg_catalog.pg_policies p WHERE p.schemaname='public' AND p.tablename='asset_pref_mirror'),
 'other_acl',(SELECT coalesce(jsonb_agg(jsonb_build_array(x.grantor,x.grantee,x.privilege_type,x.is_grantable)
   ORDER BY x.grantor,x.grantee,x.privilege_type,x.is_grantable),'[]')
   FROM pg_catalog.aclexplode(coalesce(c.relacl,pg_catalog.acldefault('r',c.relowner))) x
   WHERE NOT (x.grantee IN ('anon'::regrole::oid,'authenticated'::regrole::oid) AND x.privilege_type='TRUNCATE')),
 'other_effective',(SELECT coalesce(jsonb_agg(jsonb_build_array(r.role_name,p.privilege_name,
   pg_catalog.has_table_privilege(r.role_name,c.oid,p.privilege_name)) ORDER BY r.role_name,p.privilege_name),'[]')
   FROM (VALUES ('anon'),('authenticated'),('service_role')) r(role_name)
   CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) p(privilege_name)),
 'columns',(SELECT coalesce(jsonb_agg(jsonb_build_array(a.attname,a.attacl::text) ORDER BY a.attnum),'[]')
   FROM pg_catalog.pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
 'memberships',(SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.roleid,m.member,m.grantor),'[]') FROM pg_catalog.pg_auth_members m),
 'role_attributes',(SELECT coalesce(jsonb_agg(jsonb_build_array(r.oid,r.rolname,r.rolsuper,r.rolinherit,r.rolbypassrls) ORDER BY r.oid),'[]')
   FROM pg_catalog.pg_roles r WHERE r.rolname IN ('anon','authenticated','service_role')),
 'hierarchy',(SELECT coalesce(jsonb_agg(jsonb_build_array(i.inhparent,i.inhrelid) ORDER BY i.inhrelid),'[]') FROM pg_catalog.pg_inherits i WHERE i.inhparent=c.oid OR i.inhrelid=c.oid),
 'anon',pg_catalog.has_table_privilege('anon',c.oid,'TRUNCATE'),
 'authenticated',pg_catalog.has_table_privilege('authenticated',c.oid,'TRUNCATE'),
 'service',pg_catalog.has_table_privilege('service_role',c.oid,'TRUNCATE'))
 FROM pg_catalog.pg_class c WHERE c.oid='public.asset_pref_mirror'::regclass;"""


def run_case(service, mode, outcome, binary, migration):
    if mode not in CANDIDATES or outcome not in ('success','history_failure','candidate_failure'):
        raise RuntimeError('unapproved fixture case')
    if mode == 'pr_head_06505ee4' and outcome == 'candidate_failure':
        raise RuntimeError('current PR has no inheritance guard; case is inapplicable')
    case_started = time.monotonic()
    service.create()
    service.wait_final_postmaster()
    service.initialize()
    if outcome == 'history_failure': service.psql(HISTORY_FAILURE)
    if outcome == 'candidate_failure': service.psql(CHILD_FAILURE)
    before = json.loads(service.psql(SNAPSHOT))
    service.stage(binary, migration)
    cli_started = time.monotonic()
    cli = service.cli_push()
    cli_seconds = time.monotonic() - cli_started
    output = (cli.stdout + cli.stderr).decode('utf-8', errors='replace')
    server_logs = service.logs()
    local_pids = set(re.findall(r'\[(\d+)\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection received: host=\[local\]', server_logs))
    cli_pids = set(re.findall(r'\[(\d+)\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli(?:\s|$)', server_logs))
    if not cli_pids or not cli_pids <= local_pids:
        raise RuntimeError('CLI Unix-socket route not proven from isolated server logs: ' + output)
    pid_sql = ','.join(sorted(cli_pids))  # digits extracted from verified local logs only
    remaining = None
    for attempt in range(5):
        remaining = service.psql('SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid IN (' + pid_sql + ');').strip()
        if remaining == '0': break
        if not remaining.isdecimal(): raise RuntimeError('invalid backend monitor response')
        time.sleep(0.1)
    if remaining != '0': raise RuntimeError('CLI backend remains after process exit: ' + remaining)
    after = json.loads(service.psql(SNAPSHOT))
    history_rows = json.loads(service.psql("SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,'statement_count',coalesce(array_length(statements,1),0)) ORDER BY version),'[]') FROM supabase_migrations.schema_migrations;"))
    if not isinstance(history_rows, list) or len(history_rows) > 1:
        raise RuntimeError('unexpected synthetic history rows: ' + repr(history_rows))
    if history_rows and (history_rows[0].get('version') != VERSION or history_rows[0].get('name') != 'synthetic_acl'
                         or type(history_rows[0].get('statement_count')) is not int or history_rows[0]['statement_count'] <= 0):
        raise RuntimeError('unexpected synthetic history row: ' + repr(history_rows))
    history = str(len(history_rows))
    print('SYNTHETIC_EXECBATCH_OBSERVATION ' + json.dumps({'mode':mode, 'outcome':outcome,
        'cli_exit':cli.returncode, 'history_count':history, 'history_rows':history_rows, 'before':before, 'after':after,
        'cli_socket_pids':sorted(cli_pids), 'cli_backends_remaining':int(remaining),
        'cli_seconds':cli_seconds, 'candidate_stopped_sha':CANDIDATES[mode][1], 'cli_output':output}, sort_keys=True), flush=True)
    if outcome == 'success':
        if cli.returncode != 0 or history != '1' or after['anon'] or after['authenticated'] or not after['service']:
            raise RuntimeError('success control failed: ' + output)
    else:
        marker = 'SYNTHETIC_HISTORY_FAILURE' if outcome == 'history_failure' else 'inheritance or partition relationship requires separate review'
        errors = set(re.findall(r'\[(\d+)\] ERROR:\s+P0001:\s+' + re.escape(marker), server_logs))
        if cli.returncode == 0 or history != '0' or marker not in output or 'P0001' not in output or not (errors & cli_pids):
            raise RuntimeError('expected SQLSTATE, same-PID server evidence, or failure absent: ' + output)
        if outcome == 'history_failure':
            insert_pids = set(re.findall(r'\[(\d+)\] STATEMENT:\s+INSERT INTO supabase_migrations\.schema_migrations', server_logs))
            if 'INSERT INTO supabase_migrations.schema_migrations' not in output or not (errors & cli_pids & insert_pids):
                raise RuntimeError('history INSERT and failure did not share the CLI backend: ' + output)
    stable_keys = ('owner','rls','force','rows','policy','other_acl','other_effective',
                   'columns','memberships','role_attributes','hierarchy','service')
    if any(before[k] != after[k] for k in stable_keys):
        raise RuntimeError('unrelated synthetic table state changed')
    if outcome == 'candidate_failure' and before != after:
        raise RuntimeError('candidate guard failure changed full synthetic snapshot')
    history_effect = None
    if outcome == 'history_failure':
        if before == after:
            history_effect = 'complete_acl_unchanged'
        elif before['anon'] and before['authenticated'] and not after['anon'] and not after['authenticated']:
            # All other normalized ACL and effective privileges were checked above.
            history_effect = 'only_target_truncate_removed'
        else:
            raise RuntimeError('unexpected partial privilege change after history failure')
    return {'mode':mode,'outcome':outcome,'candidate_stopped_sha':CANDIDATES[mode][1],
        'cli_exit':cli.returncode,'history_count':int(history),'history_rows':history_rows,'before':before,'after':after,
        'history_failure_effect':history_effect,'cli_socket_pids':sorted(cli_pids),
        'cli_backends_remaining':int(remaining),'cli_seconds':cli_seconds,
        'case_seconds':time.monotonic()-case_started,'cli_output':output,
        'scope':'official CLI 2.84.2 db push, synthetic PG17 network none; production unverified'}


def run_matrix():
    """Entry for a future reviewed orchestration only. This draft is unrun."""
    if os.name != 'posix': raise RuntimeError('isolated Docker runner must be Linux')
    run_id = job_identity(os.environ)
    binary = safe_cli_binary(); candidates = candidate_pair()
    # No inherited DOCKER_HOST, credentials, HOME, proxy or shell environment.
    env = {'PATH':'/usr/bin:/bin','LANG':'C'}
    results = []
    with tempfile.TemporaryDirectory(prefix='codex-execbatch-docker-') as config:
        docker = ['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image = json.loads(subprocess.run(docker + ['image','inspect',IMAGE], env=env, capture_output=True,
            check=True, timeout=15).stdout)[0]
        for mode in ('explicit','batch','pr_head_06505ee4'):
            outcomes = ('success','history_failure') if mode == 'pr_head_06505ee4' else ('success','history_failure','candidate_failure')
            for outcome in outcomes:
                service = OwnedService(docker, env, image, run_id)
                try:
                    result = run_case(service,mode,outcome,binary,candidates[mode])
                    results.append(result)
                    print('SYNTHETIC_EXECBATCH_EVIDENCE ' + json.dumps(result,sort_keys=True),flush=True)
                except BaseException as exc:
                    evidence = {'mode':mode, 'outcome':outcome, 'run_id':service.run_id,
                        'nonce':service.nonce, 'container_id':service.cid, 'error_type':type(exc).__name__,
                        'error_summary':classify_failure(exc)}
                    if isinstance(exc, FixturePsqlError):
                        evidence['psql'] = exc.evidence
                    if service.verified:
                        try: evidence['server_logs'] = summarize_server_logs(service.logs())
                        except Exception as log_error:
                            evidence['server_logs_unavailable'] = type(log_error).__name__
                    else:
                        evidence['server_logs_unavailable'] = 'container identity not verified'
                    print('SYNTHETIC_EXECBATCH_FAILURE ' + json.dumps(evidence, sort_keys=True), flush=True)
                    raise
                finally:
                    original = sys.exc_info()[1]
                    if service.cid is not None:
                        try:
                            service.stop_owned()
                        except Exception as stop_error:
                            raise RuntimeError('owned service teardown failed: ' + str(stop_error) +
                                ('; original failure: ' + repr(original) if original else '')) from original
    return {'run_id':run_id, 'cases':results,'not_verified':['real DB','Auth','production','other PG versions',
        'concurrent role/GRANT','name replacement','deployment workflow environment',
        'history statements exact bytes/order','default container capabilities retained','actual lock hold duration'],
        'note':'history INSERT failure is deliberate and not a production change'}


if __name__ == '__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')