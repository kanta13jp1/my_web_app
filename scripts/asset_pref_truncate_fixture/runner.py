"""REVIEW ONLY: two-session primitives. No CLI, connection discovery, or DB startup.

A future separately reviewed harness must supply the exact already-initialized
idempotent fixture Service. Merely importing this file does not run SQL.
"""
import hashlib
import importlib.util
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
EXPECTED_RUNNER = HERE / 'fixture_runner.py'
EXPECTED_SHA = 'fb995082e9fd685e1d058839e7c0d64ba3ff66f589d0c084ba96eae06d7b0f5f'
DRAFT = HERE / 'candidate_single_table_lock_draft_review_stopped.sql.txt'
STOP = b"\\set ON_ERROR_STOP on\ndo $review_stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $review_stop$;\n"
STOPPED_SHA = 'a01b07f6d6dd8d31522b410bad3182b757adc90c84276212ce6fe86ea303026f'
DRAFT_SHA = '616adfba5e2b424cccbbdef847b62b1f2edadec350ca2974dfe1ca10d5eab510'


def pinned_module():
    if EXPECTED_RUNNER.is_symlink() or not EXPECTED_RUNNER.is_file() or EXPECTED_RUNNER.resolve().parent != HERE:
        raise RuntimeError('invalid fixture runner path')
    raw = EXPECTED_RUNNER.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED_SHA:
        raise RuntimeError('fixture runner hash changed: review required')
    spec = importlib.util.spec_from_file_location('isolated_fixture_runner', EXPECTED_RUNNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def candidate_parts():
    if DRAFT.is_symlink() or not DRAFT.is_file() or DRAFT.resolve().parent != HERE:
        raise RuntimeError('invalid draft path')
    stopped = DRAFT.read_bytes()
    if hashlib.sha256(stopped).hexdigest() != STOPPED_SHA:
        raise RuntimeError('stopped draft hash changed: review required')
    if not stopped.startswith(STOP) or stopped.count(STOP) != 1:
        raise RuntimeError('draft STOP is absent, misplaced or repeated')
    raw = stopped[len(STOP):]
    if hashlib.sha256(raw).hexdigest() != DRAFT_SHA:
        raise RuntimeError('unwrapped draft hash changed: review required')
    sql = raw.decode('utf-8').replace('\r\n', '\n')
    match = re.search(r'\ndo \$\$\n.*?\nend \$\$;', sql, re.S | re.I)
    if not match or len(re.findall(r'\ndo \$\$', sql, re.I)) != 1:
        raise RuntimeError('unexpected draft shape')
    return match.group(0).strip()


class Session:
    """Persistent psql owned by Service. All SQL has the fixture token guard.

    No SQL can be supplied externally via CLI. The guard is not an isolation
    boundary: job identity, image/container inspection and initialized token
    are required too. Error recovery uses only literal ROLLBACK before guard.
    """
    def __init__(self, service, module):
        if type(service) is not module.Service:
            raise RuntimeError('not the pinned fixture Service')
        module.job_identity(os.environ)
        service.inspect()
        if not re.fullmatch(r'[0-9a-f-]{36}', service.token):
            raise RuntimeError('invalid fixture token')
        self.service = service
        self.lines = queue.Queue()
        self.pending = False
        self.partial = []
        self.events = []
        self.p = subprocess.Popen(service.argv(), env=service.env, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8',
            bufsize=1)
        service.children.append(self.p)
        def reader():
            for line in self.p.stdout:
                self.lines.put(line.rstrip('\r\n'))
            self.lines.put(None)
        self.reader = threading.Thread(target=reader, daemon=True)
        self.reader.start()
        self.send("\\set ON_ERROR_STOP off\n\\set VERBOSITY verbose\nSET statement_timeout='1200ms'; SET lock_timeout='900ms';")
        self.finish()
        pid = self.run('SELECT pg_backend_pid();').strip()
        if not pid.isdecimal():
            raise RuntimeError('fixture backend pid missing')
        self.backend_pid = int(pid)

    def send(self, sql, *, recover=False):
        if self.pending or self.p.poll() is not None:
            raise RuntimeError('session already busy or exited')
        self.service.inspect()
        if '\\' in sql and not sql.startswith('\\set ON_ERROR_STOP off'):
            raise ValueError('psql metacommands forbidden in scenario SQL')
        self.marker = 'SYNTHETIC_DONE_' + uuid.uuid4().hex
        # A failed transaction rejects SELECT; ROLLBACK is the sole permitted
        # command before rechecking the token in that specific recovery path.
        before = 'ROLLBACK;\n' if recover else ''
        guard = ("SELECT EXISTS (SELECT 1 FROM public.debt_cas_fixture_guard "
                 "WHERE token=:'fixture_token'::uuid) AS fixture_ok \\gset\n"
                 "\\if :fixture_ok\n")
        body = before + guard + sql + "\n\\else\n\\echo SYNTHETIC_GUARD_FAILURE\n\\quit\n\\endif\n\\echo " + self.marker + '\n'
        self.pending = True
        self.started = time.monotonic()
        self.partial = []
        self.p.stdin.write(body)
        self.p.stdin.flush()

    def finish(self, timeout=4):
        if not self.pending:
            raise RuntimeError('no pending command')
        end = time.monotonic() + timeout
        lines = self.partial
        while True:
            remaining = end - time.monotonic()
            if remaining <= 0:
                self.events.append({'kind': 'timeout_probe', 'seconds': time.monotonic() - self.started})
                raise TimeoutError('fixture command did not finish; teardown required')
            try:
                line = self.lines.get(timeout=remaining)
            except queue.Empty:
                self.events.append({'kind': 'timeout_probe', 'seconds': time.monotonic() - self.started})
                raise TimeoutError('fixture command did not finish; teardown required') from None
            if line is None:
                raise RuntimeError('fixture session ended before marker')
            if line == self.marker:
                self.pending = False
                if 'SYNTHETIC_GUARD_FAILURE' in lines:
                    raise RuntimeError('fixture token guard failed')
                output = '\n'.join(lines)
                self.events.append({'kind': 'completed', 'seconds': time.monotonic() - self.started, 'output': output})
                return output
            lines.append(line)

    def run(self, sql, **kwargs):
        self.send(sql, **kwargs)
        return self.finish()

    def close(self):
        if self.p.poll() is None:
            self.p.terminate()
            try:
                self.p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait(timeout=3)
        self.reader.join(timeout=2)
        if self.p.poll() is None or self.reader.is_alive():
            raise RuntimeError('fixture session did not terminate')
        self.events.append({'kind': 'process_terminated', 'backend_pid': self.backend_pid, 'returncode': self.p.returncode,
                            'server_connection_absence': 'unverified; trusted harness must check pg_stat_activity'})


def open_pair(service, module):
    """A future trusted harness must call service.stop_owned() in finally."""
    a = Session(service, module)
    try:
        return a, Session(service, module)
    except BaseException:
        a.close()
        raise


def assert_state(output, sqlstate):
    if not re.search(r'ERROR:\s+' + re.escape(sqlstate) + r':', output):
        raise AssertionError('expected SQLSTATE ' + sqlstate + ': ' + output)


def assert_clean(output):
    if re.search(r'^(ERROR|FATAL|PANIC):', output, re.M):
        raise AssertionError('unexpected SQL error: ' + output)


# Scenario bodies are fixed and intentionally contain no connection settings.
# The caller must initialize a fresh verified service per case; no table/role
# cleanup against an existing cluster is permitted.
LOCK = 'LOCK TABLE ONLY public.asset_pref_mirror IN ACCESS EXCLUSIVE MODE NOWAIT;'
BASELINE = """SELECT jsonb_build_object(
 'oid', c.oid, 'owner',c.relowner,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
 'acl',c.relacl::text,'rows',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.user_id,t.pref_key),'[]') FROM ONLY public.asset_pref_mirror t),
 'hierarchy',(SELECT coalesce(jsonb_agg(jsonb_build_array(i.inhparent,i.inhrelid,ch.relkind,ch.relowner,ch.relrowsecurity,ch.relacl::text) ORDER BY i.inhparent,i.inhrelid),'[]') FROM pg_catalog.pg_inherits i JOIN pg_catalog.pg_class ch ON ch.oid=i.inhrelid WHERE i.inhparent=c.oid OR i.inhrelid=c.oid),
 'memberships',(SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.roleid,m.member,m.grantor),'[]') FROM pg_catalog.pg_auth_members m),
 'role_attributes',(SELECT coalesce(jsonb_agg(jsonb_build_array(r.oid,r.rolname,r.rolsuper,r.rolinherit,r.rolbypassrls) ORDER BY r.oid),'[]') FROM pg_catalog.pg_roles r WHERE r.rolname IN ('anon','authenticated','service_role')),
 'policies',(SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.policyname),'[]') FROM pg_catalog.pg_policies p WHERE p.schemaname='public' AND p.tablename='asset_pref_mirror'),
 'columns',(SELECT coalesce(jsonb_agg(jsonb_build_array(a.attname,a.attacl::text) ORDER BY a.attnum),'[]') FROM pg_catalog.pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped))
FROM pg_catalog.pg_class c WHERE c.oid='public.asset_pref_mirror'::regclass;"""


def nowait_rollback(a, b):
    before = a.run(BASELINE); assert_clean(before)
    assert_clean(a.run('BEGIN; LOCK TABLE ONLY public.asset_pref_mirror IN ACCESS SHARE MODE;'))
    out = b.run('BEGIN; ' + LOCK)
    assert_state(out, '55P03')
    assert_clean(b.run('SELECT 1;', recover=True))
    assert_clean(a.run('COMMIT;'))
    after = a.run(BASELINE); assert_clean(after)
    if before != after:
        raise AssertionError('NOWAIT failure altered baseline')
    return {'expected': '55P03 and baseline unchanged', 'observed': out}


def blocked_then_release(a, b, statement):
    """A holds lock, B waits; release A and require B to finish successfully.

    The short pending probe demonstrates non-completion, not lock cause; a
    future harness must additionally record pg_stat_activity wait_event=Lock.
    """
    pid = b.run('SELECT pg_backend_pid();').strip()
    if not pid.isdecimal():
        raise AssertionError('unexpected fixture backend pid: ' + pid)
    assert_clean(a.run('BEGIN; ' + LOCK))
    b.send('BEGIN; ' + statement)
    try:
        try:
            out = b.finish(timeout=0.2)
        except TimeoutError:
            out = None
        if out is not None:
            raise AssertionError('operation finished before lock release: ' + out)
        state = a.run("SELECT coalesce(wait_event_type,'') FROM pg_catalog.pg_stat_activity WHERE pid=" + pid + ';')
        assert_clean(state)
        if state.strip() != 'Lock':
            raise AssertionError('pending operation did not report Lock wait: ' + state)
        assert_clean(a.run('COMMIT;'))
        out = b.finish(timeout=3); assert_clean(out)
        assert_clean(b.run('ROLLBACK;'))
        return {'expected': 'pending then success after release', 'observed': out,
                'wait_event_type': state.strip()}
    finally:
        if a.p.poll() is None and not a.pending:
            a.run('ROLLBACK;')


def parent_child_guard(a, b, make_relation):
    assert_clean(b.run(make_relation))
    before = a.run(BASELINE); assert_clean(before)
    assert_clean(a.run('BEGIN; ' + LOCK))
    out = a.run(candidate_parts())
    if classify_inheritance_or_serialization(out, allow_serialization=False) != 'P0001':
        raise AssertionError('missing expected inheritance guard exception: ' + out)
    assert_clean(a.run('SELECT 1;', recover=True))
    after = a.run(BASELINE); assert_clean(after)
    if before != after:
        raise AssertionError('guard failure changed target baseline')
    return {'expected': 'guard raises; target baseline unchanged', 'observed': out}


# Design for additional tests: these are NOT executed by this module; a future
# harness must implement/check the noted observation and cleanup explicitly.
SCENARIOS = {
 'nowait': ('implemented', nowait_rollback),
 'read_while_locked': ('implemented', lambda a,b: blocked_then_release(a,b,'SELECT count(*) FROM public.asset_pref_mirror;')),
 'create_child_while_locked': ('implemented', lambda a,b: blocked_then_release(a,b,'CREATE TABLE public.synthetic_child () INHERITS (public.asset_pref_mirror);')),
 'existing_child_guard': ('implemented', lambda a,b: parent_child_guard(a,b,'CREATE TABLE public.synthetic_child () INHERITS (public.asset_pref_mirror);')),
 'target_is_child_guard': ('implemented', lambda a,b: parent_child_guard(a,b,'CREATE TABLE public.synthetic_parent (LIKE public.asset_pref_mirror); ALTER TABLE public.asset_pref_mirror INHERIT public.synthetic_parent;')),
 'alter_child_inherit': ('requires future harness setup', 'Create independent compatible child, then blocked_then_release with ALTER TABLE public.synthetic_child INHERIT public.asset_pref_mirror'),
 'old_repeatable_read_snapshot': ('observation, not a passing security assertion', 'A BEGIN REPEATABLE READ; establish snapshot; B creates and commits child; A locks and executes draft DO; record success/error and independently query current pg_inherits'),
 'membership_and_grant': ('observation, not a passing security assertion', 'A holds target lock; B attempts GRANT fixture role membership and GRANT TRUNCATE independently; record completion/SQLSTATE/wait_event; never infer universal locking'),
 'name_replacement_before_after_lock': ('requires future harness setup', 'Before lock, rename original and create same-name RLS table owned by postgres; record OIDs. After lock, attempt rename/drop from B and record wait. Existing draft has no immutable OID anchor.'),
 'partition_parent': ('requires future harness setup', 'Fresh fixture with partitioned parent and child; assert draft refuses and state preserved; fresh normal-table fixture separately'),
 'role_permissions': ('requires future harness setup', 'Repeat lock with minimally privileged fixture execution role; record denial and writer compatibility; fixture superuser success alone is not evidence'),
 'teardown_and_availability': ('requires future harness setup', 'Record duration, pending lock wait_event, bounded timeouts, session pids gone, service stopped; NOWAIT does not cap hold time'),
}



def repeatable_read_observation(a, b):
    assert_clean(a.run('BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT count(*) FROM pg_catalog.pg_inherits;'))
    assert_clean(b.run('CREATE TABLE public.synthetic_child () INHERITS (public.asset_pref_mirror);'))
    lock_out = a.run(LOCK)
    lock_error = classify_expected_lock_failure(lock_out, ('40001', '55P03', '57014'))
    out = 'DO not executed because lock failed' if lock_error else a.run(candidate_parts())
    candidate_error = None if lock_error else classify_inheritance_or_serialization(out, allow_serialization=True)
    a.run('SELECT 1;', recover=True)
    current = b.run("SELECT count(*) FROM pg_catalog.pg_inherits WHERE inhparent='public.asset_pref_mirror'::regclass;")
    assert_clean(current)
    if current.strip() != '1':
        raise AssertionError('independent current hierarchy observation failed: ' + current)
    accepted = not lock_error and not candidate_error
    return {'classification': 'observation', 'child_committed': True, 'lock_output': lock_out, 'candidate_sqlstate': candidate_error,
            'draft_accepted': accepted, 'risk': ('lock failed before guard; inspect SQLSTATE' if lock_error else ('guard accepted despite committed child' if accepted else 'draft raised; inspect exact cause')),
            'output': out, 'current_hierarchy': current}


def classify_expected_lock_failure(output, allowed=('55P03', '57014')):
    failures = re.findall(r'^(?:ERROR|FATAL|PANIC):.*$', output, re.M)
    if not failures:
        return None
    if len(failures) != 1:
        raise AssertionError('multiple or ambiguous SQL failures: ' + output)
    match = re.match(r'^ERROR:\s+([0-9A-Z]{5}):', failures[0])
    if not match or match.group(1) not in allowed:
        raise AssertionError('unexpected SQL failure: ' + output)
    return match.group(1)


def classify_inheritance_or_serialization(output, *, allow_serialization):
    failures = re.findall(r'^(?:ERROR|FATAL|PANIC):.*$', output, re.M)
    if not failures:
        return None
    if len(failures) != 1:
        raise AssertionError('multiple or ambiguous candidate failures: ' + output)
    match = re.match(r'^ERROR:\s+([0-9A-Z]{5}):\s*(.*)$', failures[0])
    if not match:
        raise AssertionError('unexpected candidate failure: ' + output)
    state, message = match.groups()
    if state == 'P0001' and 'inheritance or partition relationship requires separate review' in message:
        return state
    if state == '40001' and allow_serialization:
        return state
    raise AssertionError('unexpected candidate SQLSTATE: ' + output)


def observe_concurrent(a, b, statement):
    assert_clean(a.run('BEGIN; ' + LOCK))
    b.send(statement)
    try:
        try:
            out = b.finish(timeout=0.2)
            sqlstate = classify_expected_lock_failure(out)
            result = 'timeout while table locked' if sqlstate else 'completed while table locked'
        except TimeoutError:
            result = 'pending at 200ms; lock cause unverified'
            assert_clean(a.run('COMMIT;'))
            out = b.finish(timeout=3)
            sqlstate = classify_expected_lock_failure(out)
            return {'classification': 'observation', 'while_locked': result,
                    'after_release': out, 'sqlstate': sqlstate}
        assert_clean(a.run('COMMIT;'))
        return {'classification': 'observation', 'while_locked': result,
                'output': out, 'sqlstate': sqlstate}
    finally:
        if a.p.poll() is None and not a.pending:
            a.run('ROLLBACK;')


def membership_observation(a, b):
    before = a.run(BASELINE); assert_clean(before)
    assert_clean(b.run('CREATE ROLE synthetic_lock_member NOLOGIN;'))
    result = observe_concurrent(a, b, 'GRANT synthetic_lock_member TO authenticated;')
    check = b.run("SELECT pg_catalog.pg_has_role('authenticated','synthetic_lock_member','MEMBER');")
    assert_clean(check)
    result['member_after'] = check
    assert_clean(b.run('REVOKE synthetic_lock_member FROM authenticated; DROP ROLE synthetic_lock_member;'))
    after = b.run(BASELINE); assert_clean(after)
    if before != after:
        raise AssertionError('membership cleanup changed baseline')
    result['baseline_restored'] = True
    return result


def grant_observation(a, b):
    before = a.run(BASELINE); assert_clean(before)
    assert_clean(b.run('CREATE ROLE synthetic_lock_grantee NOLOGIN;'))
    result = observe_concurrent(a, b, 'GRANT TRUNCATE ON public.asset_pref_mirror TO synthetic_lock_grantee;')
    after = b.run(BASELINE); assert_clean(after)
    result['target_baseline_before'] = before
    result['target_baseline_after_grant'] = after
    assert_clean(b.run('REVOKE TRUNCATE ON public.asset_pref_mirror FROM synthetic_lock_grantee; DROP ROLE synthetic_lock_grantee;'))
    restored = b.run(BASELINE); assert_clean(restored)
    if before != restored:
        raise AssertionError('grant cleanup changed baseline')
    result['baseline_restored'] = True
    result['risk'] = 'concurrent or later GRANT requires independent control; result alone does not prove safety'
    return result


def replacement_before_lock(a, b):
    before = b.run(BASELINE); assert_clean(before)
    old = b.run("SELECT 'public.asset_pref_mirror'::regclass::oid;"); assert_clean(old)
    assert_clean(b.run('ALTER TABLE public.asset_pref_mirror RENAME TO synthetic_original; '
                       'CREATE TABLE public.asset_pref_mirror (LIKE public.synthetic_original INCLUDING ALL); '
                       'ALTER TABLE public.asset_pref_mirror ENABLE ROW LEVEL SECURITY;'))
    new = b.run("SELECT 'public.asset_pref_mirror'::regclass::oid;"); assert_clean(new)
    if old.strip() == new.strip():
        raise AssertionError('replacement did not create a distinct OID')
    assert_clean(a.run('BEGIN; ' + LOCK))
    out = a.run(candidate_parts())
    assert_clean(out)
    a.run('SELECT 1;', recover=True)
    accepted = True
    assert_clean(b.run('DROP TABLE public.asset_pref_mirror; ALTER TABLE public.synthetic_original RENAME TO asset_pref_mirror;'))
    restored = b.run(BASELINE); assert_clean(restored)
    if before != restored:
        raise AssertionError('name replacement cleanup changed baseline')
    return {'classification': 'observation', 'baseline_restored': True, 'original_oid': old, 'replacement_oid': new,
            'draft_accepted': accepted, 'output': out,
            'risk': 'draft has no pre-lock immutable OID anchor'}


def replace_after_lock(a, b):
    before = b.run(BASELINE); assert_clean(before)
    result = observe_concurrent(a, b, 'ALTER TABLE public.asset_pref_mirror RENAME TO synthetic_renamed;')
    if result.get('while_locked') == 'completed while table locked':
        result['risk'] = 'rename completed during lock: investigate'
    else:
        result['risk'] = 'pending probe needs independent wait_event evidence'
    # If rename completed, restore on the same disposable fixture only.
    check = b.run("SELECT to_regclass('public.synthetic_renamed') IS NOT NULL;")
    assert_clean(check)
    if check.strip() == 't':
        assert_clean(b.run('ALTER TABLE public.synthetic_renamed RENAME TO asset_pref_mirror;'))
    restored = b.run(BASELINE); assert_clean(restored)
    if before != restored:
        raise AssertionError('rename cleanup changed baseline')
    result['baseline_restored'] = True
    return result


def alter_existing_child(a, b):
    assert_clean(b.run('CREATE TABLE public.synthetic_child (LIKE public.asset_pref_mirror);'))
    return blocked_then_release(a, b, 'ALTER TABLE public.synthetic_child INHERIT public.asset_pref_mirror;')


SCENARIOS.update({
 'alter_child_inherit': ('implemented', alter_existing_child),
 'old_repeatable_read_snapshot': ('implemented observation', repeatable_read_observation),
 'membership': ('implemented observation', membership_observation),
 'grant': ('implemented observation', grant_observation),
 'name_replacement_before_lock': ('implemented observation', replacement_before_lock),
 'name_replacement_after_lock': ('implemented observation', replace_after_lock),
})
SCENARIOS.pop('membership_and_grant', None)
SCENARIOS.pop('name_replacement_before_after_lock', None)



def partition_parent(a, b):
    """Use only on disposable fixture; no CASCADE or broad cleanup."""
    before = b.run(BASELINE); assert_clean(before)
    assert_clean(b.run("ALTER TABLE public.asset_pref_mirror RENAME TO synthetic_original; "
        "CREATE TABLE public.asset_pref_mirror (user_id uuid NOT NULL, pref_key text NOT NULL, "
        "value jsonb NOT NULL, updated_at timestamptz NOT NULL) PARTITION BY HASH (user_id); "
        "CREATE TABLE public.synthetic_partition PARTITION OF public.asset_pref_mirror "
        "FOR VALUES WITH (MODULUS 1, REMAINDER 0); "
        "ALTER TABLE public.asset_pref_mirror ENABLE ROW LEVEL SECURITY;"))
    assert_clean(a.run('BEGIN;'))
    lock_output = a.run(LOCK)
    lock_state = classify_expected_lock_failure(lock_output, ('55P03', '57014', '40001'))
    if lock_state:
        # Only enumerated contention/serialization failures are observations.
        outcome = 'lock failed; draft DO not executed'
        out = lock_output
    else:
        out = a.run(candidate_parts())
        if not re.search(r'ERROR:\s+P0002:', out):
            raise AssertionError('partition guard did not fail with strict no-row error: ' + out)
        outcome = 'draft rejected partition parent'
    a.run('SELECT 1;', recover=True)
    assert_clean(b.run('DROP TABLE public.synthetic_partition; DROP TABLE public.asset_pref_mirror; '
                       'ALTER TABLE public.synthetic_original RENAME TO asset_pref_mirror;'))
    restored = b.run(BASELINE); assert_clean(restored)
    if before != restored:
        raise AssertionError('partition cleanup changed original baseline')
    return {'classification': 'observation' if outcome.startswith('lock failed') else 'assertion',
            'outcome': outcome, 'output': out, 'lock_sqlstate': lock_state, 'baseline_restored': True}


SCENARIOS['partition_parent'] = ('implemented', partition_parent)


if __name__ == '__main__':
    raise SystemExit('REVIEW ONLY: import from a separately reviewed, trusted isolated fixture harness; direct execution disabled')