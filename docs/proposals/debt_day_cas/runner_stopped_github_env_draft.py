"""Unconnected, synthetic-only GitHub-hosted service runner DRAFT.

Do not run until independent review and a separately reviewed workflow bind
the two service IDs, images, labels and this file to a trusted job. Environment
variables, application names and SQL markers are forgeable and do not by
themselves establish isolation. Never connect to production or a shared DB.
"""
import hashlib
import copy
import sys
import unittest
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
DATABASE = 'debt_contract'
PASSWORD = 'synthetic-debt-only'
FIXED = {'fixture_setup.sql.txt': ('d0635f7b249e26e93b3f2c2775b249e332653681e00698780f72a742affbb92d', 'a21c5b5825108b9439751b56fe099a40365e50a8019349397df7d44ef1cdf1f5'), 'fixture_v5_preseed.sql.txt': ('11a616066db4fa5784252a20ffd8c63942b3b26a7044c7f8b21c3faab11d3355', '9adb5a4d40546959bc59ae9824aab7fc82bced023bd7dd2fbea73e88b3c7f5cb'), 'candidate_v2_unreviewed.sql.txt': ('c036cec12bc4d2c371fe5af28d9125805c6630b8d714bf143846cce207eec5a7', 'dadc85d1032a47d1bd74dc68df6a9479855216d47e917be44888689af21cdcdb'), 'write_v5_unreviewed.sql.txt': ('e8f13a55397ffabd5422af6a3113eca39b967e61bc74b4883f24d9524c12af24', 'b23e65d3c00b55094a4ad83b2b226cafd824786c1805cc001909703470282614'), 'fixture_guard_v5.sql.txt': ('bf68f7193983058ad6bdde2d5a07bcfd132747cd1e3c29caee43dc021054234b', 'b928df5ea118c3f933574ed96d6ead0e884f1300432b5250ba93c430e9324a85'), 'fixture_v5_assertions.sql.txt': ('5f3ef980c776c7978c3817c4844b5c752fa3a8823fc63838482450b2125783db', '06f8c77a769a2cf51ca184fa62bd2f31fc49f745ecf04cad7ca878653f120355'), 'fixture_v5_rollback.sql.txt': ('b31137fdcda140a212f1ca9472d847ab7f69af414ede9f5d516e7e807a452265', 'f109c5b701fef429392ffd9f5fc47bfdce9a6f1a9786a0b4c6f0208388bf9fa0'), 'fixture_session_a.sql.txt': ('4e02ff550e587621fdf38ade70dca5bfca6692356d6b5c93830305fba9765b6b', 'ccdf644553a0de6808b9b8403f46051bb8d74884a6ce76b01dffa763d9e0e7c6'), 'fixture_session_b.sql.txt': ('64d43984a84203dcc7b197994bf5a630461bd7af13590af7ff07bdff73ddb2b5', 'd30e8290169e0cf91e4df24d8f87f29ca01a45d5bc0022f49ce506776ac6d73c'), 'fixture_verify_wait.sql.txt': ('96d8259d5cf828a5f8846e56080d33058a9706b7757c7e601263d5ebad6d6503', '4f8dfb3aa59451e6501d645a5ca23cabfb06a42d5effd3568d89ef6c3051ef8e'), 'fixture_verify_concurrency.sql.txt': ('618cc9d6e996d98e8fc9335f03e479cceba3e2ed1dda2ac359ae7b190448da6f', 'b7ff460231e25dd3f332e116ef40241ff5b52da015a41ab34b89aeb060a9a6ff')}
STOP = b"\\set ON_ERROR_STOP on\ndo $review_stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $review_stop$;\n"

EMPTY = r"""\set ON_ERROR_STOP on
select case when current_database()='debt_contract' and current_user='postgres'
 and current_setting('server_version_num')::int between 170000 and 179999
 and not exists (select 1 from pg_catalog.pg_roles where rolname in ('anon','authenticated','service_role'))
 and not exists (select 1 from pg_catalog.pg_namespace where nspname not in ('public','information_schema') and left(nspname,3)<>'pg_')
 and not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
                 where n.nspname='public' and c.relkind in ('r','p','v','m','f','S'))
 and not exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_extension where extname<>'plpgsql')
 then 'EMPTY_FIXTURE' else 'NOT_EMPTY' end;
"""


def decode_stopped(data, expected_stopped, expected_original):
    if hashlib.sha256(data).hexdigest() != expected_stopped:
        raise RuntimeError('stopped fixture digest mismatch')
    if not data.startswith(STOP) or data.count(STOP) != 1:
        raise RuntimeError('fixture stop is absent, misplaced or repeated')
    original = data[len(STOP):]
    if hashlib.sha256(original).hexdigest() != expected_original:
        raise RuntimeError('unwrapped fixture digest mismatch')
    return original.decode('utf-8').replace('\r\n', '\n')


def load_sources():
    result = {}
    stopped_setup = None
    for name, (stopped_sha, original_sha) in FIXED.items():
        path = HERE / 'review_stopped' / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(HERE / 'review_stopped'):
            raise RuntimeError('invalid stopped fixture input: ' + name)
        data = path.read_bytes()
        result[name] = decode_stopped(data, stopped_sha, original_sha)
        if name == 'fixture_setup.sql.txt':
            stopped_setup = data.decode('utf-8')
    if stopped_setup is None:
        raise RuntimeError('stopped setup fixture missing')
    return result, stopped_setup


def job_identity(env):
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != 'kanta13jp1/my_web_app'
        or env.get('GITHUB_JOB') != 'debt-cas-isolated'
        or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'
        or not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9]+', attempt)):
        raise RuntimeError('untrusted synthetic job identity')
    return run + '-' + attempt


def env_map(items):
    result = {}
    for item in items or []:
        if not isinstance(item, str) or '=' not in item:
            raise ValueError('invalid image or container environment')
        key, value = item.split('=', 1)
        if not key or key in result:
            raise ValueError('duplicate image or container environment')
        result[key] = value
    return result


def verify_stop_result(returncode, stdout, stderr):
    errors = re.findall(r'^ERROR:\s*(.*)$', stderr, flags=re.MULTILINE)
    if returncode != 3 or stdout.strip() or errors != ['REVIEW ONLY: execution prohibited']:
        raise RuntimeError('stopped fixture did not fail as expected')


def valid_container(info, cid, image, label, lane, network, *, running=True):
    if not all(key in info for key in ('Id','Image','Config','HostConfig','NetworkSettings','State','Mounts')):
        return False
    if not all(isinstance(info[key], dict) for key in ('Config','HostConfig','NetworkSettings','State')):
        return False
    if not isinstance(info['Mounts'], list) or not isinstance(image.get('Config'), dict):
        return False
    config, host, net = info['Config'], info['HostConfig'], info['NetworkSettings']
    image_config = image['Config']
    config_keys = ('Image','Env','Labels','Entrypoint','Cmd','User')
    image_keys = ('Env','Entrypoint','Cmd','User')
    host_keys = ('Privileged','Binds','PortBindings','PublishAllPorts','CapAdd','Devices',
                 'DeviceRequests','ExtraHosts','Links','VolumesFrom','SecurityOpt','NetworkMode',
                 'Tmpfs','PidMode','IpcMode','UsernsMode')
    if (not all(key in config for key in config_keys) or not all(key in image_config for key in image_keys)
        or not all(key in host for key in host_keys) or not all(key in net for key in ('Ports','Networks'))
        or 'Running' not in info['State']):
        return False
    if not isinstance(config['Labels'], dict):
        return False
    labels, mounts = config['Labels'], info['Mounts']
    try:
        expected_env = env_map(image_config.get('Env'))
        expected_env.update(POSTGRES_DB=DATABASE, POSTGRES_PASSWORD=PASSWORD, GITHUB_ACTIONS='true', CI='true')
        actual_env = env_map(config.get('Env'))
    except ValueError:
        return False
    ports = net['Ports']
    networks = net['Networks']
    if not isinstance(ports, dict) or not isinstance(networks, dict):
        return False
    tmpfs = host.get('Tmpfs') or {}
    options = set((tmpfs.get('/var/lib/postgresql/data') or '').split(','))
    return bool(
        info.get('Id') == cid and info.get('Image') == image.get('Id')
        and config.get('Image') == IMAGE and isinstance(info['State']['Running'], bool)
        and (not running or info['State']['Running'] is True)
        and labels.get('debt.cas.run') == label and labels.get('debt.cas.lane') == lane
        and actual_env == expected_env and actual_env.get('PGDATA') == '/var/lib/postgresql/data'
        and 'POSTGRES_INITDB_WALDIR' not in actual_env
        and all(config.get(key) == image_config.get(key) for key in ('Entrypoint', 'Cmd', 'User'))
        and host['Privileged'] is False and host['PublishAllPorts'] is False
        and not any(host.get(key) for key in ('Binds','PortBindings',
                    'CapAdd','Devices','DeviceRequests','ExtraHosts','Links','VolumesFrom','SecurityOpt'))
        and host.get('NetworkMode') == network and set(networks) == {network}
        and host['PidMode'] in ('', 'private') and host['IpcMode'] in ('', 'private')
        and host['UsernsMode'] in ('', 'private')
        and all(not binding for binding in ports.values())
        and set(tmpfs) == {'/var/lib/postgresql/data'}
        and {'rw','nosuid'} <= options and bool({'size=256m','size=268435456'} & options)
        and all(m.get('Type') == 'tmpfs' and m.get('Destination') == '/var/lib/postgresql/data' for m in mounts)
    )


class Service:
    def __init__(self, cid, lane, label, docker, env, image, network):
        self.cid, self.lane, self.label = cid, lane, label
        self.docker, self.env, self.image, self.network = docker, env, image, network
        self.token = str(uuid.uuid4())
        self.children = []
        self.inspect()

    def command(self, *args, timeout=15):
        return subprocess.run(self.docker + list(args), env=self.env, capture_output=True,
                              text=True, check=True, timeout=timeout)

    def inspect(self, *, running=True):
        info = json.loads(self.command('inspect', self.cid).stdout)[0]
        if not valid_container(info, self.cid, self.image, self.label, self.lane, self.network, running=running):
            raise RuntimeError('service identity mismatch; teardown required')
        return info

    def argv(self):
        self.inspect()
        return self.docker + ['exec', '-i', '-u', 'postgres', self.cid,
            '/usr/bin/env', '-i', 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
            '/usr/local/bin/psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
            '-v', 'fixture_token=' + self.token, '-h', '/var/run/postgresql', '-U', 'postgres', '-d', DATABASE]

    @staticmethod
    def guarded(source):
        return ("\\set ON_ERROR_STOP on\nselect 1/((count(*)=1)::int) "
                "from public.debt_cas_fixture_guard where token=:'fixture_token'::uuid;\n" + source)

    def sql(self, source, *, guarded=True):
        if guarded:
            source = self.guarded(source)
        return subprocess.run(self.argv(), input=source, env=self.env, capture_output=True,
                              text=True, check=True, timeout=30).stdout

    def start(self, source):
        child = subprocess.Popen(self.argv(), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, env=self.env, bufsize=1)
        self.children.append(child)
        output = queue.Queue()
        def collect():
            for line in child.stdout:
                output.put(line.rstrip())
        threading.Thread(target=collect, daemon=True).start()
        child.stdin.write(self.guarded(source) + '\n')
        child.stdin.flush()
        return child, output

    @staticmethod
    def wait_marker(child, output, marker, timeout=25):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if child.poll() is not None and output.empty():
                raise RuntimeError('synthetic client ended before expected marker')
            try:
                if output.get(timeout=min(.2, max(.01, deadline-time.monotonic()))) == marker:
                    return
            except queue.Empty:
                pass
        raise TimeoutError('synthetic client marker timeout')

    def initialize(self, sources, stopped_setup):
        if self.sql(EMPTY, guarded=False).strip() != 'EMPTY_FIXTURE':
            raise RuntimeError('service database is not empty')
        guard_test = subprocess.run(self.argv(), input=stopped_setup, env=self.env,
                                    capture_output=True, text=True, check=False, timeout=30)
        verify_stop_result(guard_test.returncode, guard_test.stdout, guard_test.stderr)
        if self.sql(EMPTY, guarded=False).strip() != 'EMPTY_FIXTURE':
            raise RuntimeError('guard test changed the service database')
        self.sql("\\set ON_ERROR_STOP on\ncreate table public.debt_cas_fixture_guard(token uuid primary key);\n"
                 "insert into public.debt_cas_fixture_guard values (:'fixture_token'::uuid);\n", guarded=False)
        self.sql("set codex.debt_cas_fixture='isolated-debt-cas-v2';\n" + sources['fixture_setup.sql.txt'])
        for name in ('fixture_v5_preseed.sql.txt', 'candidate_v2_unreviewed.sql.txt',
                     'write_v5_unreviewed.sql.txt', 'fixture_guard_v5.sql.txt'):
            self.sql(sources[name])

    def stop_owned(self):
        for child in self.children:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
        info = self.inspect(running=False)
        if info.get('State', {}).get('Running'):
            self.command('stop', '--time', '5', self.cid, timeout=20)
        if self.inspect(running=False).get('State', {}).get('Running'):
            raise RuntimeError('service still running; teardown required')


WAIT_PROBE = r"""select case when exists (
 select 1 from pg_catalog.pg_stat_activity a join pg_catalog.pg_stat_activity b
 on a.pid=any(pg_catalog.pg_blocking_pids(b.pid))
 where a.datname=current_database() and b.datname=current_database()
 and a.application_name='debt-cas-fixture-A' and b.application_name='debt-cas-fixture-B'
 and a.wait_event_type='Lock' and a.wait_event='advisory'
) then 'BLOCKED' else 'WAITING' end;"""


def concurrency(service, sources):
    holder_sql = ("set application_name='debt-cas-fixture-holder';\n"
                  "select pg_catalog.pg_advisory_lock(815964117);\n\\echo HOLDER_ACQUIRED\n")
    holder, qh = service.start(holder_sql)
    service.wait_marker(holder, qh, 'HOLDER_ACQUIRED')
    a, qa = service.start(sources['fixture_session_a.sql.txt'])
    service.wait_marker(a, qa, 'A_WRITE_DONE_BEFORE_COMMIT')
    b, qb = service.start(sources['fixture_session_b.sql.txt'])
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        if any(child.poll() is not None for child in (holder, a, b)):
            raise RuntimeError('synthetic session ended before lock verification')
        if service.sql(WAIT_PROBE).strip().splitlines()[-1] == 'BLOCKED':
            break
        time.sleep(.2)
    else:
        raise TimeoutError('synthetic concurrent lock timeout')
    if 'VERIFIED_B_BLOCKED_BY_A' not in service.sql(sources['fixture_verify_wait.sql.txt']).splitlines():
        raise RuntimeError('precise wait verification absent')
    holder.stdin.write("do $$ begin if not pg_catalog.pg_advisory_unlock(815964117) then "
                       "raise exception 'unlock failed'; end if; end $$;\n\\echo HOLDER_UNLOCKED\n")
    holder.stdin.flush()
    service.wait_marker(holder, qh, 'HOLDER_UNLOCKED')
    service.wait_marker(a, qa, 'A_COMMIT_DONE')
    service.wait_marker(b, qb, 'B_CONFLICT_CONFIRMED')
    for child in (holder, a, b):
        child.stdin.close()
        if child.wait(timeout=10) != 0:
            raise RuntimeError('synthetic session failed')
    clear = service.sql("select case when not exists (select 1 from pg_catalog.pg_locks "
        "where locktype='advisory' and classid=0 and objid=815964117 and objsubid=1) "
        "then 'CLEAR' else 'NOT_CLEAR' end;")
    if clear.strip().splitlines()[-1] != 'CLEAR':
        raise RuntimeError('fixture advisory lock remains; teardown required')
    service.sql(sources['fixture_verify_concurrency.sql.txt'])


def main():
    sources, stopped_setup = load_sources()  # Capture verified bytes before service access.
    label = job_identity(os.environ)
    ids = [os.environ.get('FIXTURE_SEQUENTIAL_ID', ''), os.environ.get('FIXTURE_CONCURRENCY_ID', '')]
    if ids[0] == ids[1] or any(not re.fullmatch(r'[0-9a-f]{64}', cid) for cid in ids):
        raise RuntimeError('two distinct exact service IDs required')
    network = os.environ.get('FIXTURE_NETWORK_NAME', '')
    if not re.fullmatch(r'github_network_[0-9a-f]{32}', network):
        raise RuntimeError('expected exact GitHub job network name')
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C'}
    owned = []
    with tempfile.TemporaryDirectory(prefix='debt-cas-docker-') as config:
        docker = ['/usr/bin/docker', '--config', config, '--host', 'unix:///var/run/docker.sock']
        image = json.loads(subprocess.run(docker + ['image', 'inspect', IMAGE], env=env,
            capture_output=True, text=True, check=True, timeout=15).stdout)[0]
        if IMAGE not in (image.get('RepoDigests') or []):
            raise RuntimeError('pinned image digest missing')
        try:
            for cid, lane in zip(ids, ('sequential', 'concurrency')):
                owned.append(Service(cid, lane, label, docker, env, image, network))
            seq, parallel = owned
            seq.initialize(sources, stopped_setup)
            seq.sql(sources['fixture_v5_assertions.sql.txt'])
            seq.sql(sources['fixture_v5_rollback.sql.txt'])
            parallel.initialize(sources, stopped_setup)
            concurrency(parallel, sources)
        finally:
            errors = []
            for service in reversed(owned):
                try:
                    service.stop_owned()
                except Exception:
                    errors.append(service.lane)
            if errors:
                raise RuntimeError('service teardown not verified: ' + ','.join(errors))
        print('Synthetic sequential, rollback, two-session and service-stop checks passed.')


class StoppedInputTests(unittest.TestCase):
    def test_fixed_inputs_unwrap_to_verified_originals(self):
        sources, stopped_setup = load_sources()
        self.assertEqual(set(sources), set(FIXED))
        self.assertTrue(stopped_setup.startswith(STOP.decode('utf-8')))

    def test_changed_missing_or_repeated_guard_is_rejected(self):
        name = next(iter(FIXED))
        data = (HERE / 'review_stopped' / name).read_bytes()
        stopped_sha, original_sha = FIXED[name]
        for bad in (data + b'x', data[len(STOP):], STOP + data):
            with self.subTest(size=len(bad)), self.assertRaises(RuntimeError):
                decode_stopped(bad, stopped_sha, original_sha)
        # Even with a recomputed outer hash, omission/duplication is refused.
        for bad in (data[len(STOP):], STOP + data):
            with self.assertRaises(RuntimeError):
                decode_stopped(bad, hashlib.sha256(bad).hexdigest(), original_sha)

    def test_stop_result_requires_exact_error_and_exit(self):
        valid = 'ERROR:  REVIEW ONLY: execution prohibited\nCONTEXT: synthetic\n'
        verify_stop_result(3, '', valid)
        for rc, stdout, stderr in ((0, '', valid), (3, 'unexpected', valid),
                                   (3, '', 'ERROR: other\n'),
                                   (3, '', valid + 'ERROR: another\n')):
            with self.subTest(rc=rc, stdout=stdout), self.assertRaises(RuntimeError):
                verify_stop_result(rc, stdout, stderr)

    def test_container_negative_cases(self):
        cid, net = 'a' * 64, 'github_network_' + 'b' * 32
        image = {'Id': 'sha256:test', 'Config': {'Env': ['PGDATA=/var/lib/postgresql/data'],
                  'Entrypoint': ['docker-entrypoint.sh'], 'Cmd': ['postgres'], 'User': ''}}
        config = {'Image': IMAGE, 'Env': ['PGDATA=/var/lib/postgresql/data',
                  'POSTGRES_DB=' + DATABASE, 'POSTGRES_PASSWORD=' + PASSWORD,
                  'GITHUB_ACTIONS=true', 'CI=true'],
                  'Entrypoint': ['docker-entrypoint.sh'], 'Cmd': ['postgres'], 'User': '',
                  'Labels': {'debt.cas.run': '1-1', 'debt.cas.lane': 'sequential'}}
        info = {'Id': cid, 'Image': image['Id'], 'Config': config, 'State': {'Running': True},
                'HostConfig': {'NetworkMode': net, 'Tmpfs': {'/var/lib/postgresql/data': 'rw,nosuid,size=256m'},
                    'Privileged': False, 'Binds': None, 'PortBindings': None, 'PublishAllPorts': False,
                    'CapAdd': None, 'Devices': None, 'DeviceRequests': None, 'ExtraHosts': None,
                    'Links': None, 'VolumesFrom': None, 'SecurityOpt': None,
                    'PidMode': '', 'IpcMode': 'private', 'UsernsMode': ''},
                'NetworkSettings': {'Networks': {net: {}}, 'Ports': {'5432/tcp': None}}, 'Mounts': []}
        def ok(obj): return valid_container(obj, cid, image, '1-1', 'sequential', net)
        self.assertTrue(ok(info))
        for section, key, val in [('HostConfig','PublishAllPorts',True), ('HostConfig','CapAdd',['SYS_ADMIN']),
                                  ('HostConfig','Devices',[{'PathOnHost':'/dev/x'}]), ('HostConfig','ExtraHosts',['x:1.2.3.4']),
                                  ('HostConfig','Links',['x']), ('HostConfig','VolumesFrom',['x']),
                                  ('HostConfig','PortBindings',{'5432/tcp':[{}]}), ('Config','Cmd',['other'])]:
            changed = copy.deepcopy(info); changed[section][key] = val
            with self.subTest(key=key): self.assertFalse(ok(changed))
        for extra in ('PGDATA=/elsewhere', 'POSTGRES_INITDB_WALDIR=/elsewhere', 'LD_PRELOAD=/bad'):
            changed = copy.deepcopy(info); changed['Config']['Env'].append(extra)
            with self.subTest(extra=extra): self.assertFalse(ok(changed))
        for name in ('GITHUB_ACTIONS', 'CI'):
            changed = copy.deepcopy(info)
            changed['Config']['Env'] = [x for x in changed['Config']['Env'] if not x.startswith(name + '=')]
            with self.subTest(missing_env=name): self.assertFalse(ok(changed))
            changed = copy.deepcopy(info)
            changed['Config']['Env'] = [name + '=false' if x.startswith(name + '=') else x for x in changed['Config']['Env']]
            with self.subTest(wrong_env=name): self.assertFalse(ok(changed))
            changed = copy.deepcopy(info); changed['Config']['Env'].append(name + '=true')
            with self.subTest(duplicate_env=name): self.assertFalse(ok(changed))
        changed = copy.deepcopy(info); changed['NetworkSettings']['Ports']['5432/tcp'] = [{'HostPort':'5432'}]
        self.assertFalse(ok(changed))
        for section, key in [('HostConfig','PublishAllPorts'),('HostConfig','PidMode'),
                             ('HostConfig','IpcMode'),('HostConfig','UsernsMode'),
                             ('NetworkSettings','Ports'),('NetworkSettings','Networks'),
                             ('Config','User')]:
            changed = copy.deepcopy(info); del changed[section][key]
            with self.subTest(missing=section+'.'+key): self.assertFalse(ok(changed))
        for mode in ('PidMode','IpcMode','UsernsMode'):
            changed = copy.deepcopy(info); changed['HostConfig'][mode] = 'host'
            with self.subTest(mode=mode): self.assertFalse(ok(changed))
        changed = copy.deepcopy(info); changed['NetworkSettings']['Ports'] = None
        self.assertFalse(ok(changed))
        for key in ('Privileged', 'PublishAllPorts'):
            for value in (None, 0, 'false'):
                changed = copy.deepcopy(info); changed['HostConfig'][key] = value
                with self.subTest(bool_field=key, value=value): self.assertFalse(ok(changed))
        for value in (None, 0, 1, 'true'):
            changed = copy.deepcopy(info); changed['State']['Running'] = value
            with self.subTest(running=value): self.assertFalse(ok(changed))
        changed = copy.deepcopy(info); changed['State']['Running'] = False
        self.assertFalse(ok(changed))
        self.assertTrue(valid_container(changed, cid, image, '1-1', 'sequential', net, running=False))


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        unittest.main(argv=[sys.argv[0]])
    elif len(sys.argv) == 1:
        main()
    else:
        raise SystemExit('unsupported invocation')
