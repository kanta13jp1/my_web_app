"""Extra synthetic payroll races; run only in the disposable contract database."""
import concurrent.futures
import subprocess
import time


def psql(sql):
    return subprocess.run(
        ['psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
         '-v', 'VERBOSITY=verbose', '-c', sql],
        capture_output=True, text=True, timeout=15,
    )


def checked(sql):
    result = psql(sql)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip().splitlines()[-1]


assert checked('select current_database()') == 'payroll_contract'
owner = 'aaaaaaaa-0000-0000-0000-000000000001'
account = 'aaaaaaaa-1111-1111-1111-111111111111'


def save(month, request, balance, delay=0):
    request_id = f'00000000-0000-0000-0000-{request:012d}'
    return psql(f"""begin;
      set application_name = 'payroll-uncertain-commit';
      set role authenticated;
      select set_config('request.jwt.claim.sub', '{owner}', true);
      select public.confirm_payroll_balance_observation(
        '{account}', '2030-{month:02d}-01', 'synthetic-{request}',
        '2030-{month:02d}-20', 'day', null, null, {balance},
        'synthetic source', '{request_id}', null, 'synthetic reason', true);
      select pg_sleep({delay});
      commit;""")


def counts(month):
    return checked(f"""select
      (select count(*) from public.asset_payroll_balance_observations
       where payroll_month='2030-{month:02d}-01') || '|' ||
      (select count(*) from public.asset_payroll_balance_selections
       where payroll_month='2030-{month:02d}-01') || '|' ||
      (select count(*) from public.asset_payroll_balance_selection_history
       where payroll_month='2030-{month:02d}-01')""")


# No existing selection: competing initial records cannot both become history.
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(lambda request: save(3, request, request + 700, 0.5), [20, 21]))
assert sum(result.returncode == 0 for result in results) == 1, [r.stderr for r in results]
assert '40001' in next(result.stderr for result in results if result.returncode != 0)
assert counts(3) == '1|1|1', counts(3)
print('PASS: simultaneous first saves yield one committed observation and one conflict')

# Same request sent concurrently is idempotent, including its audit history.
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(lambda _: save(4, 30, 730, 0.5), range(2)))
assert all(result.returncode == 0 for result in results), [r.stderr for r in results]
assert counts(4) == '1|1|1', counts(4)
print('PASS: simultaneous identical requests leave one observation and one audit')

# An absent read while the original transaction is pending is not a failure.
with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
    future = pool.submit(save, 5, 40, 740, 3)
    for _ in range(50):
        sleeping = checked("""select count(*) from pg_stat_activity
          where application_name='payroll-uncertain-commit'
            and wait_event='PgSleep'""")
        if sleeping == '1':
            break
        time.sleep(0.05)
    else:
        raise AssertionError('pending synthetic transaction was not observed')
    assert counts(5) == '0|0|0', counts(5)
    result = future.result(timeout=10)
    assert result.returncode == 0, result.stderr
assert counts(5) == '1|1|1', counts(5)
# Simulate a lost response by discarding it and replaying the exact request.
assert save(5, 40, 740).returncode == 0
assert counts(5) == '1|1|1', counts(5)
print('PASS: pre-commit read is empty; exact replay after delayed commit is idempotent')
