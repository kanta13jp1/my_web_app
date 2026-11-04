"""REVIEW ONLY: whole candidate SQL through isolated psql, not Supabase CLI.

Requires the hash-pinned diagnostic harness and existing verified Service.
The psql Session uses ON_ERROR_STOP=off so it remains available to observe
transaction end; real deployment client fail-fast behavior is not reproduced.
"""
import hashlib
import re

SCOPE = ('STOP-verified complete candidate SQL through psql with ON_ERROR_STOP=off; '
         'not Supabase CLI batch/history and not a production migration')
PROBE_KEY = 'synthetic_outer_boundary_probe'
PROBE_UUID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
PROBE_VALUE = '{"probe":"synthetic_outer_boundary"}'


def full_sql(scenario):
    scenario.candidate_parts()  # verifies stopped and unwrapped hashes and structure
    stopped = scenario.DRAFT.read_bytes()
    if not stopped.startswith(scenario.STOP) or stopped.count(scenario.STOP) != 1:
        raise RuntimeError('candidate STOP check failed')
    raw = stopped[len(scenario.STOP):]
    if hashlib.sha256(raw).hexdigest() != scenario.DRAFT_SHA:
        raise RuntimeError('candidate full body digest mismatch')
    return raw.decode('utf-8')  # preserve the verified bytes' line endings


def error_states(output):
    lines = re.findall(r'^(?:ERROR|FATAL|PANIC):.*$', output, re.M)
    states = []
    for line in lines:
        match = re.match(r'^ERROR:\s+([0-9A-Z]{5}):', line)
        if not match:
            raise AssertionError('unclassifiable SQL failure: ' + output)
        states.append(match.group(1))
    return states


def expect_states(output, expected):
    found = error_states(output)
    if found != expected:
        raise AssertionError('unexpected SQLSTATE sequence: ' + repr(found) + ' output=' + output)


def grants(session, scenario):
    result = session.run("SELECT pg_catalog.has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE'), "
                         "pg_catalog.has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE');")
    scenario.assert_clean(result)
    return result.strip()


def state_of(session, other, scenario):
    if type(other.backend_pid) is not int or other.backend_pid <= 0:
        raise RuntimeError('invalid fixture backend PID')
    result = session.run('SELECT state, xact_start IS NULL FROM pg_catalog.pg_stat_activity WHERE pid=' + str(other.backend_pid) + ';')
    scenario.assert_clean(result)
    return result.strip()


def probe_count(session, scenario):
    result = session.run("SELECT count(*) FROM public.asset_pref_mirror WHERE user_id='" + PROBE_UUID + "'::uuid "
                         "AND pref_key='" + PROBE_KEY + "';")
    scenario.assert_clean(result)
    return result.strip()


def insert_probe(session, scenario):
    sql = ("INSERT INTO public.asset_pref_mirror(user_id,pref_key,value) VALUES ('" + PROBE_UUID + "'::uuid,'" +
           PROBE_KEY + "','" + PROBE_VALUE + "'::jsonb);")
    scenario.assert_clean(session.run(sql))


def remove_probe(session, scenario):
    sql = ("DELETE FROM public.asset_pref_mirror WHERE user_id='" + PROBE_UUID + "'::uuid AND pref_key='" +
           PROBE_KEY + "' AND value='" + PROBE_VALUE + "'::jsonb;")
    scenario.assert_clean(session.run(sql))
    if probe_count(session, scenario) != '0':
        raise AssertionError('synthetic probe still exists after exact-target delete')


def no_outer_commit(a, b, scenario):
    before = b.run(scenario.BASELINE); scenario.assert_clean(before)
    if grants(a, scenario) != 'f|f': raise AssertionError('fixture starts with unexpected truncate')
    scenario.assert_clean(a.run('GRANT TRUNCATE ON public.asset_pref_mirror TO anon, authenticated;'))
    if grants(a, scenario) != 't|t': raise AssertionError('fixture grant setup failed')
    out = a.run(full_sql(scenario)); expect_states(out, [])
    if grants(b, scenario) != 'f|f': raise AssertionError('full SQL did not commit privilege removal')
    after = b.run(scenario.BASELINE); scenario.assert_clean(after)
    if before != after: raise AssertionError('full commit changed unrelated target baseline')
    return {'classification': 'assertion', 'mode': 'no outer transaction', 'scope': SCOPE,
            'result': 'candidate commit observed; both effective truncate grants removed', 'output': out}


def competing_lock_rollback(a, b, scenario):
    baseline = b.run(scenario.BASELINE); scenario.assert_clean(baseline)
    if grants(b, scenario) != 'f|f': raise AssertionError('fixture starts with unexpected truncate')
    scenario.assert_clean(b.run('GRANT TRUNCATE ON public.asset_pref_mirror TO anon, authenticated;'))
    before = b.run(scenario.BASELINE); scenario.assert_clean(before)
    scenario.assert_clean(a.run('BEGIN; LOCK TABLE ONLY public.asset_pref_mirror IN ACCESS SHARE MODE;'))
    out = b.run(full_sql(scenario)); expect_states(out, ['55P03', '25P02'])
    idle = state_of(a, b, scenario)
    if idle != 'idle|t': raise AssertionError('candidate did not end failed transaction: ' + idle)
    after = a.run(scenario.BASELINE); scenario.assert_clean(after)
    if before != after or grants(a, scenario) != 't|t':
        raise AssertionError('lock failure changed granted fixture state')
    scenario.assert_clean(a.run('COMMIT;'))
    scenario.assert_clean(b.run('REVOKE TRUNCATE ON public.asset_pref_mirror FROM anon, authenticated;'))
    restored = b.run(scenario.BASELINE); scenario.assert_clean(restored)
    if baseline != restored: raise AssertionError('fixture grant cleanup changed baseline')
    return {'classification': 'assertion', 'mode': 'no outer transaction, conflicting reader',
            'scope': SCOPE, 'sqlstates': ['55P03', '25P02'], 'post_transaction': idle, 'output': out}


def outer_rr_rollback(a, b, scenario):
    baseline = b.run(scenario.BASELINE); scenario.assert_clean(baseline)
    if probe_count(b, scenario) != '0': raise AssertionError('probe key already exists')
    scenario.assert_clean(a.run('BEGIN ISOLATION LEVEL REPEATABLE READ;'))
    isolation = a.run('SHOW transaction_isolation;'); scenario.assert_clean(isolation)
    if isolation.strip() != 'repeatable read': raise AssertionError('unexpected fixture isolation')
    insert_probe(a, scenario)
    out = a.run(full_sql(scenario)); expect_states(out, ['P0001'])
    if 'read committed transaction isolation required' not in out:
        raise AssertionError('isolation guard message missing')
    if 'there is already a transaction in progress' not in out:
        raise AssertionError('nested BEGIN warning missing')
    idle = state_of(b, a, scenario)
    if idle != 'idle|t': raise AssertionError('outer transaction did not end: ' + idle)
    if probe_count(b, scenario) != '0': raise AssertionError('outer RR probe survived error')
    after = b.run(scenario.BASELINE); scenario.assert_clean(after)
    if after != baseline: raise AssertionError('outer RR error changed target baseline')
    return {'classification': 'assertion', 'mode': 'outer REPEATABLE READ', 'scope': SCOPE,
            'sqlstates': ['P0001'], 'post_transaction': idle, 'outer_probe_visible': False, 'output': out}


def outer_rc_boundary(a, b, scenario):
    baseline = b.run(scenario.BASELINE); scenario.assert_clean(baseline)
    if probe_count(b, scenario) != '0': raise AssertionError('probe key already exists')
    scenario.assert_clean(a.run('BEGIN ISOLATION LEVEL READ COMMITTED;'))
    isolation = a.run('SHOW transaction_isolation;'); scenario.assert_clean(isolation)
    if isolation.strip() != 'read committed': raise AssertionError('unexpected fixture isolation')
    insert_probe(a, scenario)
    if probe_count(b, scenario) != '0': raise AssertionError('uncommitted probe was visible')
    out = a.run(full_sql(scenario)); expect_states(out, [])
    if 'there is already a transaction in progress' not in out:
        raise AssertionError('nested BEGIN warning missing')
    idle = state_of(b, a, scenario)
    if idle != 'idle|t' or probe_count(b, scenario) != '1':
        raise AssertionError('candidate COMMIT did not establish expected outer boundary: ' + idle)
    later_rollback = a.run('ROLLBACK;'); scenario.assert_clean(later_rollback)
    if probe_count(b, scenario) != '1':
        raise AssertionError('probe unexpectedly disappeared after later rollback')
    remove_probe(b, scenario)
    after = b.run(scenario.BASELINE); scenario.assert_clean(after)
    if after != baseline: raise AssertionError('probe cleanup changed target baseline')
    return {'classification': 'assertion_and_risk', 'mode': 'outer READ COMMITTED', 'scope': SCOPE,
            'post_candidate_transaction': idle, 'outer_probe_visible_after_later_rollback': True,
            'risk': 'candidate COMMIT committed the caller outer transaction',
            'output': out, 'later_rollback_output': later_rollback}


if __name__ == '__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')