"""REVIEW ONLY. No direct execution; requires separately reviewed cloud entrypoint.

The caller must hash-pin this module and the workflow/head. The job must own
one ephemeral, pinned service on a private GitHub Actions network. This module
never accepts a DSN or host and must never be used against a real database.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
SCENARIO = HERE / 'runner.py'
SCENARIO_SHA = 'baa33235cd9bc7746d2772d114d429d26ad88142ad0ef2c68b23ec027f93f6cb'
FIXTURE = HERE / 'fixture_runner.py'
FIXTURE_SHA = 'fb995082e9fd685e1d058839e7c0d64ba3ff66f589d0c084ba96eae06d7b0f5f'


def checked_file(path, digest):
    if path.is_symlink() or not path.is_file() or path.resolve().parent != HERE:
        raise RuntimeError('invalid pinned sibling: ' + path.name)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise RuntimeError('pinned sibling hash changed: ' + path.name)


def load_scenario():
    checked_file(SCENARIO, SCENARIO_SHA)
    checked_file(FIXTURE, FIXTURE_SHA)
    spec = importlib.util.spec_from_file_location('lock_review_scenario', SCENARIO)
    scenario = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scenario)
    return scenario


CHILD_CLEANUP = """DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='synthetic_child' AND c.relkind='r'
     AND pg_catalog.pg_get_userbyid(c.relowner)='postgres') THEN
  RAISE EXCEPTION 'unexpected synthetic child'; END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_inherits i WHERE i.inhrelid='public.synthetic_child'::regclass
   AND i.inhparent <> 'public.asset_pref_mirror'::regclass) THEN
  RAISE EXCEPTION 'unexpected synthetic child parent'; END IF;
 DROP TABLE public.synthetic_child;
END $$;"""
PARENT_CLEANUP = """DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname='synthetic_parent' AND c.relkind='r'
     AND pg_catalog.pg_get_userbyid(c.relowner)='postgres') OR
    NOT EXISTS (SELECT 1 FROM pg_catalog.pg_inherits i
      WHERE i.inhparent='public.synthetic_parent'::regclass AND i.inhrelid='public.asset_pref_mirror'::regclass) OR
    EXISTS (SELECT 1 FROM pg_catalog.pg_inherits i
      WHERE i.inhparent='public.synthetic_parent'::regclass AND i.inhrelid <> 'public.asset_pref_mirror'::regclass)
 THEN RAISE EXCEPTION 'unexpected synthetic parent'; END IF;
 ALTER TABLE public.asset_pref_mirror NO INHERIT public.synthetic_parent;
 DROP TABLE public.synthetic_parent;
END $$;"""

# Explicit closed list: no caller-supplied SQL, table name, or cleanup path.
CASES = (
 ('nowait', None),
 ('read_while_locked', None),
 ('create_child_while_locked', None),
 ('alter_child_inherit', CHILD_CLEANUP),
 ('existing_child_guard', CHILD_CLEANUP),
 ('target_is_child_guard', PARENT_CLEANUP),
 ('old_repeatable_read_snapshot', CHILD_CLEANUP),
 ('membership', None),
 ('grant', None),
 ('name_replacement_before_lock', None),
 ('name_replacement_after_lock', None),
 ('partition_parent', None),
)


def one_shot(service, sql):
    """Use only the identity-checked fixture argv; register every child."""
    service.inspect()
    proc = subprocess.Popen(service.argv(), env=service.env, stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
    service.children.append(proc)
    try:
        stdout, stderr = proc.communicate(service.guarded(sql), timeout=8)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate(timeout=3)
        raise RuntimeError('monitor timed out; isolated service must stop') from None
    if proc.returncode != 0:
        raise RuntimeError('monitor failed: ' + stderr)
    return stdout.strip().splitlines()


def ensure_backends_gone(service, pids):
    if not pids or any(type(pid) is not int or pid <= 0 for pid in pids):
        raise RuntimeError('missing synthetic backend PIDs')
    pid_sql = ','.join(str(pid) for pid in pids)
    # Probe process connects to the same verified disposable fixture only.
    # Its own short-lived backend is not among the recorded A/B PIDs.
    for attempt in range(3):
        output = one_shot(service, 'SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid IN (' + pid_sql + ');')
        if output == ['1', '0']:
            return {'pids': pids, 'remaining': 0, 'attempts': attempt + 1}
        if len(output) != 2 or output[0] != '1' or not output[1].isdigit():
            raise RuntimeError('unexpected backend monitor output: ' + repr(output))
        if attempt < 2:
            time.sleep(0.1)
    raise RuntimeError('fixture backend remains after both clients stopped')


def run_case(service, module, scenario, name, cleanup, expected_baseline):
    a = b = None
    pids = []
    try:
        a, b = scenario.open_pair(service, module)
        pids = [a.backend_pid, b.backend_pid]
        before = a.run(scenario.BASELINE); scenario.assert_clean(before)
        if before != expected_baseline:
            raise RuntimeError('case started with changed target baseline: ' + name)
        kind, function = scenario.SCENARIOS[name]
        if not kind.startswith('implemented') or not callable(function):
            raise RuntimeError('case is not implemented: ' + name)
        result = function(a, b)
        if cleanup:
            scenario.assert_clean(b.run(cleanup))
        absent = b.run("SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('synthetic_child','synthetic_parent','synthetic_original','synthetic_partition'); SELECT count(*) FROM pg_catalog.pg_roles WHERE rolname IN ('synthetic_lock_member','synthetic_lock_grantee');")
        scenario.assert_clean(absent)
        if absent.splitlines() != ['0', '0']:
            raise RuntimeError('synthetic object or role remains: ' + name + ': ' + absent)
        after = b.run(scenario.BASELINE); scenario.assert_clean(after)
        if after != expected_baseline:
            raise RuntimeError('case cleanup failed baseline comparison: ' + name)
        events = {'a': list(a.events), 'b': list(b.events)}
    finally:
        # Never attempt broad SQL cleanup after an exception. Abort the service.
        # A still registered child also remains covered by service.stop_owned().
        original_failure = sys.exc_info()[1]
        close_errors = []
        for session in (b, a):
            if session is not None:
                try:
                    session.close()
                except Exception as exc:
                    close_errors.append(str(exc))
        if close_errors:
            raise RuntimeError('session teardown failed: ' + '; '.join(close_errors) + ('; original failure: ' + repr(original_failure) if original_failure else '')) from original_failure
    gone = ensure_backends_gone(service, pids)
    return {'case': name, 'case_type': kind, 'result': result,
            'target_baseline_restored': True, 'backends': gone, 'events': events}


def run_in_verified_job():
    """Return evidence to a hash-pinned workflow. Never connect to an external DB.

    Workflow must fix its own exact head, changed paths, sibling hashes, matrix,
    service image/network and max-parallel, and must not enable production.
    """
    scenario = load_scenario()
    module = scenario.pinned_module()
    label = module.job_identity(os.environ)
    cid = os.environ.get('FIXTURE_SEQUENTIAL_ID', '')
    network = os.environ.get('FIXTURE_NETWORK_NAME', '')
    if not re.fullmatch(r'[0-9a-f]{64}', cid) or not re.fullmatch(r'github_network_[0-9a-f]{32}', network):
        raise RuntimeError('invalid fixture service identity')
    if os.environ.get('SYNTHETIC_PG_MAJOR') not in ('15', '16', '17') or module.PG_MAJOR != os.environ['SYNTHETIC_PG_MAJOR']:
        raise RuntimeError('missing or inconsistent PG major')
    scenario.candidate_parts()  # hash + STOP verification only; no SQL execution
    # load_sources checks all stopped hashes and equality with the fixed project
    # migration. It requires placement at scripts/<fixture>/ under that tree.
    sources, stopped_setup = module.load_sources()
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C'}
    with tempfile.TemporaryDirectory(prefix='truncate-lock-fixture-docker-') as config:
        docker = ['/usr/bin/docker', '--config', config, '--host', 'unix:///var/run/docker.sock']
        inspected = subprocess.run(docker + ['image', 'inspect', module.IMAGE], env=env,
            capture_output=True, text=True, check=True, timeout=15)
        image = json.loads(inspected.stdout)[0]
        if module.IMAGE not in (image.get('RepoDigests') or []):
            raise RuntimeError('pinned image digest missing')
        service = None
        results = []
        try:
            service = module.Service(cid, 'sequential', label, docker, env, image, network)
            service.initialize(sources, stopped_setup)
            initial = one_shot(service, scenario.BASELINE)
            if len(initial) != 2 or initial[0] != '1':
                raise RuntimeError('unexpected initial baseline')
            baseline = initial[1]
            for name, cleanup in CASES:
                result = run_case(service, module, scenario, name, cleanup, baseline)
                results.append(result)
                print('SYNTHETIC_CASE_EVIDENCE ' + json.dumps(result, ensure_ascii=True), flush=True)
        except BaseException as exc:
            print('SYNTHETIC_CASE_FAILURE ' + json.dumps({'completed_cases': [r['case'] for r in results],
                'error_type': type(exc).__name__, 'error': str(exc)}, ensure_ascii=True), flush=True)
            raise
        finally:
            original_failure = sys.exc_info()[1]
            if service is not None:
                try:
                    service.stop_owned()
                except Exception as stop_error:
                    raise RuntimeError('service stop failed: ' + str(stop_error) +
                        ('; original failure: ' + repr(original_failure) if original_failure else '')) from original_failure
        return {'pg_major': module.PG_MAJOR, 'cases': results,
                'service_stop': 'confirmed by existing Service.stop_owned',
                'not_verified': ['real DB', 'real Auth', 'production availability',
                                 'minimal execution privileges', 'all concurrent DDL paths',
                                 'workflow/head binding'],
                'note': 'observations are not production safety or approval evidence'}


if __name__ == '__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')