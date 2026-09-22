import concurrent.futures
import subprocess
import uuid

def sql(q):
    return subprocess.check_output(['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-c', q], text=True).strip()

def call(user):
    return sql(f"set role service_role; select public.reserve_jev_mario_call('{user}');").splitlines()[-1]

user = str(uuid.uuid4())
assert call(user) == 't'
# Leave three reservations before the minute cap; concurrent requests must not overspend.
sql("update public.jev_expense_quota set used=297 where scope like 'mario:%:minute'")
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
    result = list(pool.map(call, [user] * 12))
assert result.count('t') == 3, result
sql("update public.jev_expense_quota set bucket=bucket-1 where scope like 'mario:%:minute'; update public.jev_expense_quota set used=1000 where scope like 'mario:%:day' and scope<>'mario:global:day'")
assert call(user) == 'f'
sql("update public.jev_expense_quota set used=3000 where scope='mario:global:day'")
assert call(str(uuid.uuid4())) == 'f'
sql("update public.jev_expense_quota set bucket=bucket-1")
assert call(user) == 't'
assert sql("select count(*) from public.jev_expense_quota where scope not like 'mario:%'") == '0'
assert sql("select has_function_privilege('authenticated','public.reserve_jev_mario_call(uuid)','execute')") == 'f'
assert sql("select has_function_privilege('anon','public.reserve_jev_mario_call(uuid)','execute')") == 'f'
print('Mario quota concurrency, global/day/minute limits, rollover, isolation and privileges passed')
