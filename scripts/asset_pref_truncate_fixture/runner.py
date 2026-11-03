"""Synthetic-only GitHub-hosted PR fixture; never connect to an existing DB.
Identity variables and SQL marker alone are forgeable. Review the job boundary.
"""
import hashlib, copy, sys, unittest, json, os, re, subprocess, tempfile, uuid
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ALLOWED_IMAGES = {
    '15': 'postgres@sha256:7da5d534f1ffcdb2f69efa6e466a7a29ff89eefd611c7b50c4d69aa77fd4a822',
    '16': 'postgres@sha256:b95b87e93ceb7594715d5c71fb6e09f6fc878851ab537735d617325eb9ba8b1b',
    '17': 'postgres@sha256:0b81cec82228160abfa753aeaad0609b709eb26eeb950f2e404ad2326e1cc370',
}
PG_MAJOR = os.environ.get('SYNTHETIC_PG_MAJOR', '17')
if PG_MAJOR not in ALLOWED_IMAGES:
    raise RuntimeError('Unsupported synthetic Postgres version')
IMAGE = ALLOWED_IMAGES[PG_MAJOR]

DATABASE = 'debt_contract'

PASSWORD = 'synthetic-debt-only'

STOP = b"\\set ON_ERROR_STOP on\ndo $review_stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $review_stop$;\n"

EMPTY = r"""\set ON_ERROR_STOP on
select case when current_database()='debt_contract' and current_user='postgres'
 and current_setting('server_version_num')::int / 10000 = :fixture_pg_major
 and not exists (select 1 from pg_catalog.pg_roles where rolname in ('anon','authenticated','service_role'))
 and not exists (select 1 from pg_catalog.pg_namespace where nspname not in ('public','information_schema') and left(nspname,3)<>'pg_')
 and not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
                 where n.nspname='public' and c.relkind in ('r','p','v','m','f','S'))
 and not exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace where n.nspname='public')
 and not exists (select 1 from pg_catalog.pg_extension where extname<>'plpgsql')
 then 'EMPTY_FIXTURE' else 'NOT_EMPTY' end;
"""

FIXED = {'fixture_setup.sql.txt': ('d0635f7b249e26e93b3f2c2775b249e332653681e00698780f72a742affbb92d', 'a21c5b5825108b9439751b56fe099a40365e50a8019349397df7d44ef1cdf1f5'), 'revoke_fixture_setup_v5_review_stopped.sql.txt': ('bb00057978b59a73230faced9df06e5894fa1c2a51b9acd910f9f47bd8a63e0f', '89da4d121f8896e416e3ca43d60bb63268d5b108df4d3a22407fe339bd6aca38'), 'revoke_fixture_negative_v3_review_stopped.sql.txt': ('9f52ac20a5751644c895518e195c05af8433df721ccaf7b15876695a04951c86', '62eff32b4eb1615c11d555df0f4e1c16346f5ec78f1e346eea621050d92e5eeb'), 'revoke_fixture_positive_v3_review_stopped.sql.txt': ('690600999315da035a81675736d054760bad73ef880c2c3f08b8e9b581328c81', '5fe4b14fbce247463eb07d9aa9419c6af9c4eb6a42ce6bbcbd5765133d36f01a'), 'revoke_truncate_candidate_review_stopped.sql.txt': ('4408fe5d7a3b22a32fb0e564c82b9ea8929bba15cac0e4e0dc3b21459aa990bc', '26795c9a6ac7d91c266f55244b585321583f24e920d5ba5600cda0fb9667b34c')}
MIGRATION_SHA = '26795c9a6ac7d91c266f55244b585321583f24e920d5ba5600cda0fb9667b34c'

def decode_stopped(data, expected_stopped, expected_original):
    if hashlib.sha256(data).hexdigest() != expected_stopped:
        raise RuntimeError('stopped fixture digest mismatch')
    if not data.startswith(STOP) or data.count(STOP) != 1:
        raise RuntimeError('fixture stop is absent, misplaced or repeated')
    original = data[len(STOP):]
    if hashlib.sha256(original).hexdigest() != expected_original:
        raise RuntimeError('unwrapped fixture digest mismatch')
    return original.decode('utf-8').replace('\r\n', '\n')


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
    image_keys = ('Env','Entrypoint','Cmd')
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
        and all(config.get(key) == image_config.get(key) for key in ('Entrypoint', 'Cmd'))
        and type(config['User']) is str and config['User'] == ''
        and ('User' not in image_config or (type(image_config['User']) is str and image_config['User'] == ''))
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


def inspect_shape_labels(info, image):
    # The labels and inspected key names are literal, not derived from input.
    if not isinstance(info, dict):
        return ['SHAPE_INFO_TYPE']
    if not isinstance(image, dict):
        return ['SHAPE_IMAGE_TYPE']
    labels = []
    for key, label in (('Id', 'SHAPE_INFO_ID_MISSING'), ('Image', 'SHAPE_INFO_IMAGE_MISSING'),
            ('Config', 'SHAPE_INFO_CONFIG_MISSING'), ('HostConfig', 'SHAPE_INFO_HOST_MISSING'),
            ('NetworkSettings', 'SHAPE_INFO_NETWORK_MISSING'), ('State', 'SHAPE_INFO_STATE_MISSING'),
            ('Mounts', 'SHAPE_INFO_MOUNTS_MISSING')):
        if key not in info: labels.append(label)
    if labels: return labels
    for key, label in (('Config', 'SHAPE_INFO_CONFIG_TYPE'), ('HostConfig', 'SHAPE_INFO_HOST_TYPE'),
            ('NetworkSettings', 'SHAPE_INFO_NETWORK_TYPE'), ('State', 'SHAPE_INFO_STATE_TYPE')):
        if not isinstance(info[key], dict): labels.append(label)
    if not isinstance(info['Mounts'], list): labels.append('SHAPE_INFO_MOUNTS_TYPE')
    if 'Config' not in image: labels.append('SHAPE_IMAGE_CONFIG_MISSING')
    elif not isinstance(image['Config'], dict): labels.append('SHAPE_IMAGE_CONFIG_TYPE')
    if labels: return labels
    config, host, network, state, img = info['Config'], info['HostConfig'], info['NetworkSettings'], info['State'], image['Config']
    for obj, entries in (
        (config, (('Image','SHAPE_CONFIG_IMAGE_MISSING'), ('Env','SHAPE_CONFIG_ENV_MISSING'),
            ('Labels','SHAPE_CONFIG_LABELS_MISSING'), ('Entrypoint','SHAPE_CONFIG_ENTRYPOINT_MISSING'),
            ('Cmd','SHAPE_CONFIG_CMD_MISSING'), ('User','SHAPE_CONFIG_USER_MISSING'))),
        (img, (('Env','SHAPE_IMAGE_ENV_MISSING'), ('Entrypoint','SHAPE_IMAGE_ENTRYPOINT_MISSING'),
            ('Cmd','SHAPE_IMAGE_CMD_MISSING'))),
        (host, (('Privileged','SHAPE_HOST_PRIVILEGED_MISSING'), ('Binds','SHAPE_HOST_BINDS_MISSING'),
            ('PortBindings','SHAPE_HOST_PORTBINDINGS_MISSING'), ('PublishAllPorts','SHAPE_HOST_PUBLISHALLPORTS_MISSING'),
            ('CapAdd','SHAPE_HOST_CAPADD_MISSING'), ('Devices','SHAPE_HOST_DEVICES_MISSING'),
            ('DeviceRequests','SHAPE_HOST_DEVICEREQUESTS_MISSING'), ('ExtraHosts','SHAPE_HOST_EXTRAHOSTS_MISSING'),
            ('Links','SHAPE_HOST_LINKS_MISSING'), ('VolumesFrom','SHAPE_HOST_VOLUMESFROM_MISSING'),
            ('SecurityOpt','SHAPE_HOST_SECURITYOPT_MISSING'), ('NetworkMode','SHAPE_HOST_NETWORKMODE_MISSING'),
            ('Tmpfs','SHAPE_HOST_TMPFS_MISSING'), ('PidMode','SHAPE_HOST_PIDMODE_MISSING'),
            ('IpcMode','SHAPE_HOST_IPCMODE_MISSING'), ('UsernsMode','SHAPE_HOST_USERNSMODE_MISSING'))),
        (network, (('Ports','SHAPE_NETWORK_PORTS_MISSING'), ('Networks','SHAPE_NETWORK_NETWORKS_MISSING'))),
        (state, (('Running','SHAPE_STATE_RUNNING_MISSING'),))):
        for key, label in entries:
            if key not in obj: labels.append(label)
    if 'Labels' in config and not isinstance(config['Labels'], dict): labels.append('SHAPE_CONFIG_LABELS_TYPE')
    return labels


def inspect_failure_categories(info, cid, image, label, lane, network, *, running=True):
    # Diagnostics are fixed symbols only. This does not authorize the service;
    # valid_container remains the sole decision. Never include values or reprs.
    try:
        shape = inspect_shape_labels(info, image)
        if shape:
            return shape
        config, host, net, state = (info[k] for k in ('Config', 'HostConfig', 'NetworkSettings', 'State'))
        img = image['Config']
        out = []
        if (info['Id'] != cid or info['Image'] != image.get('Id') or config['Image'] != IMAGE
            or not isinstance(state['Running'], bool) or (running and state['Running'] is not True)
            or config['Labels'].get('debt.cas.run') != label or config['Labels'].get('debt.cas.lane') != lane):
            out.append('IDENTITY')
        try:
            expected = env_map(img.get('Env'))
            expected.update(POSTGRES_DB=DATABASE, POSTGRES_PASSWORD=PASSWORD, GITHUB_ACTIONS='true', CI='true')
            actual = env_map(config.get('Env'))
            if actual != expected or actual.get('PGDATA') != '/var/lib/postgresql/data' or 'POSTGRES_INITDB_WALDIR' in actual:
                out.append('ENVIRONMENT')
        except (ValueError, TypeError):
            out.append('ENVIRONMENT')
        if (any(config.get(k) != img.get(k) for k in ('Entrypoint', 'Cmd'))
            or type(config['User']) is not str or config['User'] != ''
            or ('User' in img and (type(img['User']) is not str or img['User'] != ''))):
            out.append('IMAGE_CONFIG')
        if (host['Privileged'] is not False or host['PublishAllPorts'] is not False
            or any(host.get(k) for k in ('Binds', 'PortBindings', 'CapAdd', 'Devices', 'DeviceRequests',
                'ExtraHosts', 'Links', 'VolumesFrom', 'SecurityOpt'))
            or any(host[k] not in ('', 'private') for k in ('PidMode', 'IpcMode', 'UsernsMode'))):
            out.append('HOST_POLICY')
        ports, networks = net['Ports'], net['Networks']
        if (not isinstance(ports, dict) or not isinstance(networks, dict)
            or host.get('NetworkMode') != network or (isinstance(networks, dict) and set(networks) != {network})
            or (isinstance(ports, dict) and any(ports.values()))):
            out.append('NETWORK')
        tmpfs = host.get('Tmpfs') or {}
        options = set((tmpfs.get('/var/lib/postgresql/data') or '').split(','))
        if (set(tmpfs) != {'/var/lib/postgresql/data'} or not {'rw', 'nosuid'} <= options
            or not ({'size=256m', 'size=268435456'} & options)
            or any(m.get('Type') != 'tmpfs' or m.get('Destination') != '/var/lib/postgresql/data' for m in info['Mounts'])):
            out.append('MOUNTS')
        return out or ['UNCLASSIFIED']
    except Exception:
        return ['DIAGNOSTIC_UNAVAILABLE']


def verify_revoke_expected_failure(returncode, stdout, stderr):
    errors = re.findall(r'^ERROR:\s*(.*)$', stderr, flags=re.MULTILINE)
    if returncode != 3 or stdout.strip() != '1' or errors != ['remaining effective truncate privilege']:
        raise RuntimeError('synthetic revoke did not fail for the expected fixed reason')


def verify_missing_start_failure(returncode, stdout, stderr):
    errors = re.findall(r'^ERROR:\s*(.*)$', stderr, flags=re.MULTILINE)
    if returncode != 3 or stdout.strip() != '1' or errors != ['unexpected starting truncate privilege']:
        raise RuntimeError('synthetic drift did not fail for the expected reason')


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
        try:
            valid = valid_container(info, self.cid, self.image, self.label, self.lane, self.network, running=running)
        except Exception:
            raise RuntimeError('service identity mismatch; teardown required: INSPECT_INVALID') from None
        if not valid:
            cats = inspect_failure_categories(info, self.cid, self.image, self.label, self.lane, self.network, running=running)
            raise RuntimeError('service identity mismatch; teardown required: ' + ','.join(cats)) from None
        return info

    def argv(self):
        self.inspect()
        return self.docker + ['exec', '-i', '-u', 'postgres', self.cid,
            '/usr/bin/env', '-i', 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
            f'/usr/lib/postgresql/{PG_MAJOR}/bin/psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
            '-v', 'fixture_token=' + self.token, '-v', 'fixture_pg_major=' + PG_MAJOR, '-h', '/var/run/postgresql', '-U', 'postgres', '-d', DATABASE]

    @staticmethod
    def guarded(source):
        return ("\\set ON_ERROR_STOP on\nselect 1/((count(*)=1)::int) "
                "from public.debt_cas_fixture_guard where token=:'fixture_token'::uuid;\n" + source)

    def sql(self, source, *, guarded=True):
        if guarded:
            source = self.guarded(source)
        return subprocess.run(self.argv(), input=source, env=self.env, capture_output=True,
                              text=True, check=True, timeout=30).stdout

    def expect_revoke_failure(self, source):
        result = subprocess.run(self.argv(), input=self.guarded(source), env=self.env,
            capture_output=True, text=True, check=False, timeout=30)
        verify_revoke_expected_failure(result.returncode, result.stdout, result.stderr)

    def expect_missing_start_failure(self, source):
        result = subprocess.run(self.argv(), input=self.guarded(source), env=self.env,
            capture_output=True, text=True, check=False, timeout=30)
        verify_missing_start_failure(result.returncode, result.stdout, result.stderr)

    def expect_fixed_failure(self, source, expected):
        result = subprocess.run(self.argv(), input=self.guarded(source), env=self.env,
            capture_output=True, text=True, check=False, timeout=30)
        errors = re.findall(r'^ERROR:\s*(.*)$', result.stderr, flags=re.MULTILINE)
        if result.returncode != 3 or result.stdout.strip() != '1' or errors != [expected]:
            raise RuntimeError('synthetic guard did not fail for the expected reason')

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



def revoke_checks(service, sources):
    if 'SYNTHETIC_REVOKE_SETUP_READY' not in service.sql(sources['revoke_fixture_setup_v5_review_stopped.sql.txt']).splitlines():
        raise RuntimeError('synthetic revoke setup verification absent')
    candidate = sources['revoke_truncate_candidate_review_stopped.sql.txt']
    service.expect_revoke_failure(candidate)
    if 'SYNTHETIC_REVOKE_ROLLBACK_VERIFIED' not in service.sql(sources['revoke_fixture_negative_v3_review_stopped.sql.txt']).splitlines():
        raise RuntimeError('synthetic revoke rollback verification absent')
    if service.sql(candidate).strip() != '1':
        raise RuntimeError('synthetic successful revoke output mismatch')
    if 'SYNTHETIC_REVOKE_POSITIVE_VERIFIED' not in service.sql(sources['revoke_fixture_positive_v3_review_stopped.sql.txt']).splitlines():
        raise RuntimeError('synthetic revoke positive verification absent')


SNAPSHOT = r"""select jsonb_build_object(
  'acl', (select jsonb_agg(to_jsonb(a) order by a.grantee,a.privilege_type,a.grantor) from pg_catalog.pg_class c cross join lateral pg_catalog.aclexplode(c.relacl) a where c.oid='public.asset_pref_mirror'::regclass),
  'relation', (select jsonb_build_object('owner',relowner,'rls',relrowsecurity,'forced',relforcerowsecurity) from pg_catalog.pg_class where oid='public.asset_pref_mirror'::regclass),
  'rows', (select jsonb_agg(to_jsonb(t) order by t.user_id,t.pref_key) from public.asset_pref_mirror t),
  'policies', (select jsonb_agg(to_jsonb(p) order by p.policyname) from pg_catalog.pg_policies p where p.schemaname='public' and p.tablename='asset_pref_mirror'),
  'members', (select jsonb_agg(to_jsonb(m) order by m.roleid,m.member) from pg_catalog.pg_auth_members m where m.member='authenticated'::regrole),
  'columns', (select jsonb_agg(jsonb_build_object('name',a.attname,'acl',a.attacl) order by a.attname) from pg_catalog.pg_attribute a where a.attrelid='public.asset_pref_mirror'::regclass and a.attnum>0 and not a.attisdropped)
)::text;"""


def fail_without_change(service, candidate, kind):
    before = service.sql(SNAPSHOT)
    if kind == 'missing':
        service.expect_missing_start_failure(candidate)
    elif kind == 'inherited':
        service.expect_revoke_failure(candidate)
    else:
        service.expect_fixed_failure(candidate, kind)
    if service.sql(SNAPSHOT) != before:
        raise RuntimeError('rejected migration changed synthetic state')


def drift_checks(service, sources):
    candidate = sources['revoke_truncate_candidate_review_stopped.sql.txt']
    # The existing fail-closed policy deliberately rejects privilege drift.
    fail_without_change(service, candidate, 'missing')
    check = """select case when
      not has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      not has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_BOTH_ABSENT' else 'INVALID' end;"""
    if 'EXPECTED_BOTH_ABSENT' not in service.sql(check).splitlines():
        raise RuntimeError('missing-grant rejection changed privileges')
    service.sql('grant truncate on public.asset_pref_mirror to authenticated;')
    fail_without_change(service, candidate, 'missing')
    check = """select case when
      not has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_ANON_ABSENT' else 'INVALID' end;"""
    if 'EXPECTED_ANON_ABSENT' not in service.sql(check).splitlines():
        raise RuntimeError('partial-grant rejection changed privileges')
    service.sql('revoke truncate on public.asset_pref_mirror from authenticated; grant truncate on public.asset_pref_mirror to anon;')
    fail_without_change(service, candidate, 'missing')
    check = """select case when
      has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      not has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_AUTH_ABSENT' else 'INVALID' end;"""
    if 'EXPECTED_AUTH_ABSENT' not in service.sql(check).splitlines():
        raise RuntimeError('partial-grant rejection changed privileges')
    service.sql('grant truncate on public.asset_pref_mirror to authenticated;')
    if service.sql(candidate).strip() != '1':
        raise RuntimeError('synthetic regrant retry did not apply')
    if 'EXPECTED_BOTH_ABSENT' not in service.sql("""select case when
      not has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      not has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_BOTH_ABSENT' else 'INVALID' end;""").splitlines():
        raise RuntimeError('synthetic regrant retry left unexpected privileges')
    service.sql('grant truncate on public.asset_pref_mirror to anon;')
    service.sql('grant truncate on public.asset_pref_mirror to public;')
    fail_without_change(service, candidate, 'inherited')
    check = """select case when
      has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_PUBLIC_REMAINS' else 'INVALID' end;"""
    if 'EXPECTED_PUBLIC_REMAINS' not in service.sql(check).splitlines():
        raise RuntimeError('PUBLIC-grant rollback changed privileges')
    service.sql('revoke truncate on public.asset_pref_mirror from public; grant truncate on public.asset_pref_mirror to anon, authenticated; alter table public.asset_pref_mirror disable row level security;')
    fail_without_change(service, candidate, 'query returned no rows')
    check = """select case when
      not (select relrowsecurity from pg_catalog.pg_class where oid='public.asset_pref_mirror'::regclass) and
      has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_RLS_GUARD' else 'INVALID' end;"""
    if 'EXPECTED_RLS_GUARD' not in service.sql(check).splitlines():
        raise RuntimeError('RLS guard changed privileges')
    service.sql('alter table public.asset_pref_mirror enable row level security; create role synthetic_other_owner nologin; alter table public.asset_pref_mirror owner to synthetic_other_owner;')
    fail_without_change(service, candidate, 'unexpected owner')
    check = """select case when
      (select pg_get_userbyid(relowner) = 'synthetic_other_owner' from pg_catalog.pg_class where oid='public.asset_pref_mirror'::regclass) and
      has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') and
      has_table_privilege('service_role','public.asset_pref_mirror','TRUNCATE')
      then 'EXPECTED_OWNER_GUARD' else 'INVALID' end;"""
    if 'EXPECTED_OWNER_GUARD' not in service.sql(check).splitlines():
        raise RuntimeError('owner guard changed privileges')


def load_sources():
    result = {}
    stopped_setup = None
    for name, (outer, inner) in FIXED.items():
        path = HERE / name
        if path.is_symlink() or not path.is_file() or path.resolve().parent != HERE:
            raise RuntimeError('invalid stopped fixture')
        data = path.read_bytes()
        result[name] = decode_stopped(data, outer, inner)
        if name == 'fixture_setup.sql.txt': stopped_setup = data.decode('utf-8')
    path = ROOT / 'supabase/migrations/20261103063701_restrict_asset_pref_mirror_truncate.sql'
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
        raise RuntimeError('invalid migration path')
    migration = path.read_bytes()
    candidate = (HERE / 'revoke_truncate_candidate_review_stopped.sql.txt').read_bytes()
    # Recheck exactly the captured candidate bytes, then require full-byte equality.
    outer, inner = FIXED['revoke_truncate_candidate_review_stopped.sql.txt']
    decode_stopped(candidate, outer, inner)
    if hashlib.sha256(migration).hexdigest() != MIGRATION_SHA or migration != candidate[len(STOP):]:
        raise RuntimeError('migration differs from reviewed fixture')
    if stopped_setup is None: raise RuntimeError('stopped setup missing')
    return result, stopped_setup


def job_identity(env):
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != 'kanta13jp1/my_web_app' or env.get('GITHUB_JOB') != 'debt-cas-isolated'
        or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'
        or not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9]+', attempt)):
        raise RuntimeError('untrusted synthetic job identity')
    return run + '-' + attempt


def main():
    sources, stopped_setup = load_sources()
    label = job_identity(os.environ)
    cid = os.environ.get('FIXTURE_SEQUENTIAL_ID', '')
    network = os.environ.get('FIXTURE_NETWORK_NAME', '')
    if not re.fullmatch(r'[0-9a-f]{64}', cid) or not re.fullmatch(r'github_network_[0-9a-f]{32}', network):
        raise RuntimeError('invalid service identity')
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C'}
    with tempfile.TemporaryDirectory(prefix='truncate-fixture-docker-') as config:
        docker = ['/usr/bin/docker', '--config', config, '--host', 'unix:///var/run/docker.sock']
        image = json.loads(subprocess.run(docker + ['image', 'inspect', IMAGE], env=env,
            capture_output=True, text=True, check=True, timeout=15).stdout)[0]
        if IMAGE not in (image.get('RepoDigests') or []): raise RuntimeError('pinned digest missing')
        service = None
        try:
            service = Service(cid, 'sequential', label, docker, env, image, network)
            service.initialize(sources, stopped_setup)
            revoke_checks(service, sources)
            drift_checks(service, sources)
        finally:
            if service is not None: service.stop_owned()
        print('Synthetic revoke checks and service stop passed.')


class UnitTests(unittest.TestCase):
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
        image_without_user = copy.deepcopy(image); del image_without_user['Config']['User']
        self.assertTrue(valid_container(info, cid, image_without_user, '1-1', 'sequential', net))
        for value in (None, 0, False, 'postgres', '0'):
            modified_image = copy.deepcopy(image); modified_image['Config']['User'] = value
            with self.subTest(image_user=value):
                self.assertFalse(valid_container(info, cid, modified_image, '1-1', 'sequential', net))
                self.assertIn('IMAGE_CONFIG', inspect_failure_categories(info, cid, modified_image, '1-1', 'sequential', net))
            modified_container = copy.deepcopy(info); modified_container['Config']['User'] = value
            with self.subTest(container_user=value):
                self.assertFalse(ok(modified_container))
                self.assertIn('IMAGE_CONFIG', inspect_failure_categories(modified_container, cid, image, '1-1', 'sequential', net))
        modified_container = copy.deepcopy(info); del modified_container['Config']['User']
        self.assertFalse(ok(modified_container))
        self.assertIn('SHAPE_CONFIG_USER_MISSING', inspect_failure_categories(modified_container, cid, image, '1-1', 'sequential', net))
        diagnostic_cases = [
            ('ENVIRONMENT', 'Config', 'Env', ['sensitive=do-not-print']),
            ('IDENTITY', 'Config', 'Image', 'sensitive=do-not-print'),
            ('IMAGE_CONFIG', 'Config', 'Cmd', ['sensitive=do-not-print']),
            ('HOST_POLICY', 'HostConfig', 'IpcMode', 'sensitive=do-not-print'),
            ('NETWORK', 'HostConfig', 'NetworkMode', 'sensitive=do-not-print'),
            ('MOUNTS', 'HostConfig', 'Tmpfs', {}),
        ]
        for expected_category, section, key, value in diagnostic_cases:
            changed = copy.deepcopy(info); changed[section][key] = value
            self.assertFalse(ok(changed))
            cats = inspect_failure_categories(changed, cid, image, '1-1', 'sequential', net)
            with self.subTest(category=expected_category):
                self.assertIn(expected_category, cats)
                self.assertNotIn('sensitive', ','.join(cats))
        self.assertIn('SHAPE_INFO_ID_MISSING', inspect_failure_categories({}, cid, image, '1-1', 'sequential', net))
        for section, key, label in (
            ('Config', 'Image', 'SHAPE_CONFIG_IMAGE_MISSING'),
            ('HostConfig', 'IpcMode', 'SHAPE_HOST_IPCMODE_MISSING'),
            ('NetworkSettings', 'Ports', 'SHAPE_NETWORK_PORTS_MISSING'),
            ('State', 'Running', 'SHAPE_STATE_RUNNING_MISSING'),
        ):
            changed = copy.deepcopy(info); del changed[section][key]
            self.assertFalse(ok(changed))
            self.assertIn(label, inspect_failure_categories(changed, cid, image, '1-1', 'sequential', net))
        for section, label in (('Config', 'SHAPE_INFO_CONFIG_TYPE'), ('Mounts', 'SHAPE_INFO_MOUNTS_TYPE')):
            changed = copy.deepcopy(info); changed[section] = 'sensitive=do-not-print'
            self.assertFalse(ok(changed))
            cats = inspect_failure_categories(changed, cid, image, '1-1', 'sequential', net)
            self.assertIn(label, cats); self.assertNotIn('sensitive', ','.join(cats))
        changed = copy.deepcopy(info); changed['Config']['Labels'] = 'sensitive=do-not-print'
        self.assertFalse(ok(changed))
        self.assertIn('SHAPE_CONFIG_LABELS_TYPE', inspect_failure_categories(changed, cid, image, '1-1', 'sequential', net))
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


    def test_stop_result_requires_exact_error_and_exit(self):
        valid = 'ERROR:  REVIEW ONLY: execution prohibited\nCONTEXT: synthetic\n'
        verify_stop_result(3, '', valid)
        for rc, stdout, stderr in ((0, '', valid), (3, 'unexpected', valid),
                                   (3, '', 'ERROR: other\n'),
                                   (3, '', valid + 'ERROR: another\n')):
            with self.subTest(rc=rc, stdout=stdout), self.assertRaises(RuntimeError):
                verify_stop_result(rc, stdout, stderr)


    def test_captured_inputs_and_guard_negatives(self):
        sources, stopped = load_sources()
        self.assertEqual(set(sources), set(FIXED))
        self.assertTrue(stopped.startswith(STOP.decode()))
        for name,(outer,inner) in FIXED.items():
            data=(HERE/name).read_bytes()
            for invalid in (data+b'x', data[len(STOP):], STOP+data):
                with self.subTest(name=name), self.assertRaises(RuntimeError):
                    decode_stopped(invalid, outer, inner)

    def test_fixed_failure(self):
        expected='ERROR:  remaining effective truncate privilege\nCONTEXT: synthetic\n'
        verify_revoke_expected_failure(3,'1\n',expected)
        for code,out,err in ((0,'1',expected),(3,'',expected),(3,'1','ERROR: other\n')):
            with self.assertRaises(RuntimeError): verify_revoke_expected_failure(code,out,err)

    def test_sequential_failure_stops_following_steps(self):
        class Fake:
            def __init__(self, fail=None): self.calls,self.fail=[],fail
            def sql(self,value):
                self.calls.append(value)
                if value == self.fail: raise RuntimeError('fake failure')
                return {'setup':'SYNTHETIC_REVOKE_SETUP_READY','negative':'SYNTHETIC_REVOKE_ROLLBACK_VERIFIED','candidate':'1','positive':'SYNTHETIC_REVOKE_POSITIVE_VERIFIED'}.get(value,'')
            def expect_revoke_failure(self,value):
                self.calls.append('expected-'+value)
                if self.fail == 'expected-candidate': raise RuntimeError('fake failure')
        sources={'revoke_fixture_setup_v5_review_stopped.sql.txt':'setup', 'revoke_fixture_negative_v3_review_stopped.sql.txt':'negative', 'revoke_fixture_positive_v3_review_stopped.sql.txt':'positive', 'revoke_truncate_candidate_review_stopped.sql.txt':'candidate'}
        expected=['setup','expected-candidate','negative','candidate','positive']
        good=Fake(); revoke_checks(good,sources); self.assertEqual(good.calls,expected)
        for fail in expected:
            bad=Fake(fail)
            with self.subTest(fail=fail), self.assertRaises(RuntimeError): revoke_checks(bad,sources)
            self.assertEqual(bad.calls,expected[:expected.index(fail)+1])


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']: unittest.main(argv=[sys.argv[0]])
    elif len(sys.argv) == 1: main()
    else: raise SystemExit('unsupported invocation')
