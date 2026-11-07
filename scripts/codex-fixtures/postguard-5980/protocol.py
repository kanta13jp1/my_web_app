"""Driver-independent post-guard protocol. No Docker or database imports.

An adapter must independently prove every supplied fact. Fake tests exercise
ordering only; this module is not proof of actual PostgreSQL behavior.
"""
import hashlib

MIGRATION_SHA256 = '24e38d3b06d1aeb5d5fd6bfea2bec64c303d4fdad9a45b51f0af980a48cf9db8'
HISTORY_SQL = "INSERT INTO fixture_history.migrations(version) VALUES ('20261103063701');"

class Unknown(RuntimeError):
    pass


def require(condition, label):
    if condition is not True:
        raise Unknown(label)


def _pid(value):
    return type(value) is int and 1 <= value <= 2147483647


def execute(driver, migration):
    """Run one race. Any missing evidence or cleanup failure is non-success.

    This function has no route to execute SQL except the supplied driver, and
    never accepts a DSN or caller-supplied SQL. Driver must only expose a fresh
    owned synthetic server verified by independently reviewed runtime guards.
    """
    require(type(migration) is bytes and hashlib.sha256(migration).hexdigest() == MIGRATION_SHA256,
            'migration_digest')
    provision_attempted = False
    result = None
    failure = None
    try:
        provision_attempted = True
        identity = driver.provision()
        require(type(identity) is dict and identity.get('owned') is True and
                identity.get('verified_image') is True and identity.get('network_none') is True and
                identity.get('no_host_mounts_or_ports') is True and identity.get('fresh_nonce') is True,
                'container_identity')
        baseline = driver.bootstrap()
        require(type(baseline) is dict and baseline.get('fresh_synthetic_db') is True and
                baseline.get('pg17') is True and baseline.get('target_rls_postgres') is True and
                baseline.get('fixture_parent_truncate') is True and baseline.get('member') is False and
                baseline.get('anon_direct') is True and baseline.get('auth_direct') is True and
                baseline.get('anon_effective') is True and baseline.get('auth_effective') is True and
                type(baseline.get('history_count')) is int and baseline['history_count'] == 0 and
                type(baseline.get('other_acl_fingerprint')) is str and
                len(baseline['other_acl_fingerprint']) == 64 and
                all(c in '0123456789abcdef' for c in baseline['other_acl_fingerprint']),
                'baseline')
        c = driver.open_session('C')
        a = driver.open_session('A')
        b = driver.open_session('B')
        require(all(type(x) is dict and _pid(x.get('pid')) and x.get('unix_socket') is True for x in (a,b,c)), 'session_identity')
        require(len({a['pid'],b['pid'],c['pid']}) == 3 and
                a.get('system_id') is not None and a.get('system_id') == b.get('system_id') == c.get('system_id'),
                'backend_separation')
        require(driver.c_hold_barrier(c['pid']) is True, 'holder_lock')
        guard = driver.a_begin_and_guard(a['pid'], migration)
        require(type(guard) is dict and guard.get('pid') == a['pid'] and guard.get('guard_ok') is True and
                type(guard.get('txid')) is str and guard['txid'].isdigit(), 'guard_confirmation')
        require(driver.a_send_history(a['pid'], HISTORY_SQL) is True, 'history_submission')
        wait = driver.c_observe_wait(c['pid'], a['pid'])
        require(type(wait) is dict and wait.get('a_pid') == a['pid'] and wait.get('c_pid') == c['pid'] and
                wait.get('txid') == guard['txid'] and wait.get('query') == HISTORY_SQL and
                wait.get('a_waits_exact_lock') is True and wait.get('c_holds_exact_lock') is True,
                'history_barrier')
        grant = driver.b_commit_membership(b['pid'])
        require(type(grant) is dict and grant.get('pid') == b['pid'] and grant.get('committed') is True,
                'grant_commit')
        after_b = driver.c_observe_after_b(c['pid'], a['pid'])
        require(type(after_b) is dict and after_b.get('member') is True and after_b.get('member_inherit') is True and
                after_b.get('a_still_waits') is True and after_b.get('c_still_holds') is True and
                after_b.get('a_pid') == a['pid'] and after_b.get('txid') == guard['txid'],
                'grant_before_release')
        require(driver.c_release_barrier(c['pid']) is True, 'barrier_release')
        committed = driver.a_finish(a['pid'])
        require(type(committed) is dict and committed.get('pid') == a['pid'] and
                committed.get('commit_ok') is True, 'candidate_commit')
        final = driver.c_final_observation(c['pid'])
        require(type(final) is dict and type(final.get('history_count')) is int and final['history_count'] == 1 and final.get('member') is True and final.get('member_inherit') is True and
                type(final.get('anon_direct')) is bool and type(final.get('auth_direct')) is bool and
                type(final.get('anon_effective')) is bool and type(final.get('auth_effective')) is bool and
                final.get('other_acl_fingerprint') == baseline['other_acl_fingerprint'], 'final_observation')
        require(final['anon_direct'] is False and final['auth_direct'] is False, 'direct_revoke_unproven')
        result = {'outcome': 'race_observed' if (final['anon_effective'] or final['auth_effective']) else 'no_race_observed',
                  'anon_effective': final['anon_effective'], 'auth_effective': final['auth_effective'],
                  'history_count': 1, 'b_committed_before_release': True,
                  'a_pid': a['pid'], 'b_pid': b['pid'], 'c_pid': c['pid'],
                  'a_txid': guard['txid'], 'a_waited_exact_lock': True,
                  'c_held_exact_lock': True, 'anon_direct': final['anon_direct'],
                  'auth_direct': final['auth_direct'],
                  'other_acl_fingerprint': final['other_acl_fingerprint']}
    except BaseException as error:
        failure = error
    finally:
        if provision_attempted:
            try:
                cleanup = driver.cleanup()
                require(type(cleanup) is dict and cleanup.get('owned_clients_stopped') is True and
                        cleanup.get('owned_container_removed') is True and
                        cleanup.get('inspect_absent') is True and cleanup.get('list_absent') is True,
                        'cleanup_unproven')
            except BaseException as error:
                failure = error
    if failure is not None:
        raise Unknown('observation_or_cleanup_incomplete') from failure
    return result
