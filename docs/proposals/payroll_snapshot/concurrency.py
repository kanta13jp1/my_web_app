"""Run only against the disposable payroll_contract GitHub test database."""
import concurrent.futures
import subprocess

def psql(sql):
    return subprocess.run(['psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-c', sql], capture_output=True, text=True)

database = psql('select current_database()')
assert database.returncode == 0 and database.stdout.strip() == 'payroll_contract'
current = psql('select observation_id from public.asset_payroll_balance_selections').stdout.strip()
assert len(current) == 36

def correct(request):
    return psql(f"""begin;
      set role authenticated;
      select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', true);
      select pg_sleep(0.2);
      select public.test_save({request}, {600 + request}, '{current}');
      commit;""")

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(correct, [10, 11]))
assert sum(result.returncode == 0 for result in results) == 1, [r.stderr for r in results]
failed = next(result for result in results if result.returncode != 0)
assert '40001' in failed.stderr, failed.stderr
counts = psql('select (select count(*) from public.asset_payroll_balance_observations), (select count(*) from public.asset_payroll_balance_selection_history)')
assert counts.returncode == 0 and counts.stdout.strip() == '3|3', counts.stdout
print('PASS: one concurrent correction commits, stale correction and observation roll back atomically')
