-- Runtime PostgreSQL contract for Issue #1233. Any mismatch raises and fails
-- the Testcontainers smoke transaction.

insert into auth.users (id)
values
  ('00000000-0000-4000-8000-000000001233'),
  ('00000000-0000-4000-8000-000000001234'),
  ('00000000-0000-4000-8000-000000001235'),
  ('00000000-0000-4000-8000-000000001236'),
  ('00000000-0000-4000-8000-000000001237')
on conflict (id) do nothing;

-- Supabase grants authenticated table DML at the platform layer and relies on
-- RLS for tenant isolation. Grant only the tables this contract exercises;
-- changing ALTER DEFAULT PRIVILEGES here would leak broad DML into unrelated
-- fixtures that run later in the shared disposable database.
grant select, insert, update, delete
  on table public.hub_data,
    public.daily_habits,
    public.daily_habit_logs
  to authenticated;

do $contract$
declare
  v_signature text;
begin
  foreach v_signature in array array[
    'public.analyze_habit_resource_efficiency(integer)',
    'public.consume_resource_optimizer_ai_quota()'
  ] loop
    if exists (
      select 1
      from pg_catalog.pg_proc as procedure
      cross join lateral pg_catalog.aclexplode(
        coalesce(
          procedure.proacl,
          pg_catalog.acldefault('f', procedure.proowner)
        )
      ) as privilege
      where procedure.oid = v_signature::regprocedure
        and privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ) then
      raise exception 'PUBLIC can execute %', v_signature;
    end if;
    if pg_catalog.has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'anon can execute %', v_signature;
    end if;
    if not pg_catalog.has_function_privilege(
      'authenticated',
      v_signature,
      'EXECUTE'
    ) then
      raise exception 'authenticated cannot execute %', v_signature;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'daily_habits',
        'daily_habit_logs',
        'resource_optimizer_ai_quota'
      )
      and relation.relrowsecurity
    group by namespace.nspname
    having count(*) = 3
  ) then
    raise exception 'Issue #1233 tables do not all have RLS enabled';
  end if;
end;
$contract$;

-- Build one tenant through the authenticated/RLS boundary. Six explicit
-- self-reports plus one default-proxy row prove that defaults are excluded.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001233',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.hub_data (id, source, metadata)
values (
  '00000000-0000-4000-8000-000000012331',
  'goal',
  '{"user_id":"00000000-0000-4000-8000-000000001233"}'::jsonb
);

insert into public.daily_habits (
  id,
  user_id,
  title,
  goal_id,
  goal_title
)
values (
  '00000000-0000-4000-8000-000000112331',
  '00000000-0000-4000-8000-000000001233',
  'Issue 1233 tenant A habit',
  '00000000-0000-4000-8000-000000012331',
  'Tenant A goal'
);

insert into public.daily_habit_logs (
  user_id,
  habit_id,
  completed_date,
  goal_id,
  goal_title,
  time_cost_minutes,
  fatigue_score,
  goal_contribution_score,
  goal_contribution_measurement_source
)
select
  '00000000-0000-4000-8000-000000001233',
  '00000000-0000-4000-8000-000000112331',
  current_date - sample_number,
  '00000000-0000-4000-8000-000000012331',
  'Tenant A goal',
  sample_number * 10,
  sample_number,
  sample_number * 10,
  'self_reported_goal_contribution_proxy'
from generate_series(1, 6) as sample(sample_number);

insert into public.daily_habit_logs (
  user_id,
  habit_id,
  completed_date,
  goal_id,
  goal_title,
  time_cost_minutes,
  fatigue_score,
  goal_contribution_score
)
values (
  '00000000-0000-4000-8000-000000001233',
  '00000000-0000-4000-8000-000000112331',
  current_date - 7,
  '00000000-0000-4000-8000-000000012331',
  'Tenant A goal',
  70,
  7,
  70
);

do $contract$
declare
  v_analysis record;
  v_source text;
begin
  select goal_contribution_measurement_source
    into v_source
  from public.daily_habit_logs
  where habit_id = '00000000-0000-4000-8000-000000112331'
    and completed_date = current_date - 7;
  if v_source is distinct from 'habit_default_proxy' then
    raise exception 'default measurement source mismatch: %', v_source;
  end if;

  select * into v_analysis
  from public.analyze_habit_resource_efficiency(90);
  if not found
    or v_analysis.habit_id is distinct from
      '00000000-0000-4000-8000-000000112331'::uuid
    or v_analysis.sample_count is distinct from 6::bigint
    or v_analysis.performance_measurement_source is distinct from
      'self_reported_goal_contribution_proxy'
    or v_analysis.has_sufficient_data is distinct from false
    or v_analysis.insufficient_data_reason is distinct from
      'minimum_7_samples_required'
    or v_analysis.time_performance_correlation is not null
    or v_analysis.fatigue_performance_correlation is not null
    or v_analysis.overall_time_performance_correlation is not null
    or v_analysis.overall_fatigue_performance_correlation is not null
    or v_analysis.is_pareto_optimal is distinct from false
  then
    raise exception 'six-sample/default exclusion mismatch: %',
      row_to_json(v_analysis);
  end if;

  begin
    insert into public.daily_habit_logs (
      user_id,
      habit_id,
      completed_date,
      goal_contribution_measurement_source
    ) values (
      '00000000-0000-4000-8000-000000001233',
      '00000000-0000-4000-8000-000000112331',
      current_date - 30,
      'unverified_inference'
    );
    raise exception 'invalid measurement source was accepted';
  exception when check_violation then
    null;
  end;
end;
$contract$;
reset role;

-- Create a second tenant and prove both positive own-row access and negative
-- cross-tenant reads/writes, including cross-tenant goal attachment.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001234',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.hub_data (id, source, metadata)
values (
  '00000000-0000-4000-8000-000000012332',
  'goal',
  '{"user_id":"00000000-0000-4000-8000-000000001234"}'::jsonb
);

insert into public.daily_habits (
  id,
  user_id,
  title,
  goal_id,
  goal_title
)
values (
  '00000000-0000-4000-8000-000000112332',
  '00000000-0000-4000-8000-000000001234',
  'Issue 1233 tenant B habit',
  '00000000-0000-4000-8000-000000012332',
  'Tenant B goal'
);

insert into public.daily_habit_logs (
  user_id,
  habit_id,
  completed_date,
  goal_id,
  goal_title,
  time_cost_minutes,
  fatigue_score,
  goal_contribution_score
)
values (
  '00000000-0000-4000-8000-000000001234',
  '00000000-0000-4000-8000-000000112332',
  current_date - 1,
  '00000000-0000-4000-8000-000000012332',
  'Tenant B goal',
  15,
  2,
  20
);

do $contract$
declare
  v_count bigint;
  v_rows bigint;
begin
  select count(*) into v_count from public.daily_habits;
  if v_count is distinct from 1::bigint then
    raise exception 'tenant B habit visibility mismatch: %', v_count;
  end if;
  select count(*) into v_count from public.daily_habit_logs;
  if v_count is distinct from 1::bigint then
    raise exception 'tenant B log visibility mismatch: %', v_count;
  end if;
  select count(*) into v_count from public.hub_data;
  if v_count is distinct from 1::bigint then
    raise exception 'tenant B goal visibility mismatch: %', v_count;
  end if;
  select count(*) into v_count
  from public.analyze_habit_resource_efficiency(90);
  if v_count is distinct from 0::bigint then
    raise exception 'default-only tenant leaked into analysis: %', v_count;
  end if;

  update public.daily_habits
  set title = 'cross-tenant overwrite'
  where id = '00000000-0000-4000-8000-000000112331';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'tenant B updated tenant A habit';
  end if;

  delete from public.daily_habit_logs
  where habit_id = '00000000-0000-4000-8000-000000112331';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'tenant B deleted tenant A logs';
  end if;

  update public.hub_data
  set source = 'cross-tenant overwrite'
  where id = '00000000-0000-4000-8000-000000012331';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'tenant B updated tenant A goal';
  end if;

  begin
    insert into public.daily_habit_logs (
      user_id,
      habit_id,
      completed_date
    ) values (
      '00000000-0000-4000-8000-000000001234',
      '00000000-0000-4000-8000-000000112331',
      current_date - 30
    );
    raise exception 'cross-tenant habit log was accepted';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.daily_habit_logs (
      user_id,
      habit_id,
      completed_date,
      goal_id
    ) values (
      '00000000-0000-4000-8000-000000001234',
      '00000000-0000-4000-8000-000000112332',
      current_date - 31,
      '00000000-0000-4000-8000-000000012331'
    );
    raise exception 'cross-tenant log goal was accepted';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.daily_habits (
      id,
      user_id,
      title,
      goal_id
    ) values (
      '00000000-0000-4000-8000-000000112333',
      '00000000-0000-4000-8000-000000001234',
      'forged cross-tenant goal',
      '00000000-0000-4000-8000-000000012331'
    );
    raise exception 'cross-tenant goal attachment was accepted';
  exception when insufficient_privilege then
    null;
  end;
end;
$contract$;
reset role;

-- Seven samples without outcome/resource variance still cannot produce a
-- defensible correlation or Pareto classification.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001236',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.hub_data (id, source, metadata)
values (
  '00000000-0000-4000-8000-000000012336',
  'goal',
  '{"user_id":"00000000-0000-4000-8000-000000001236"}'::jsonb
);

insert into public.daily_habits (
  id,
  user_id,
  title,
  goal_id,
  goal_title
)
values (
  '00000000-0000-4000-8000-000000112336',
  '00000000-0000-4000-8000-000000001236',
  'Issue 1233 no-variance habit',
  '00000000-0000-4000-8000-000000012336',
  'No-variance goal'
);

insert into public.daily_habit_logs (
  user_id,
  habit_id,
  completed_date,
  goal_id,
  goal_title,
  time_cost_minutes,
  fatigue_score,
  goal_contribution_score,
  goal_contribution_measurement_source
)
select
  '00000000-0000-4000-8000-000000001236',
  '00000000-0000-4000-8000-000000112336',
  current_date - sample_number,
  '00000000-0000-4000-8000-000000012336',
  'No-variance goal',
  20,
  2,
  50,
  'self_reported_goal_contribution_proxy'
from generate_series(1, 7) as sample(sample_number);

do $contract$
declare
  v_analysis record;
begin
  select * into v_analysis
  from public.analyze_habit_resource_efficiency(90);
  if not found
    or v_analysis.sample_count is distinct from 7::bigint
    or v_analysis.has_sufficient_data is distinct from false
    or v_analysis.insufficient_data_reason is distinct from
      'insufficient_performance_variance'
    or v_analysis.time_performance_correlation is not null
    or v_analysis.fatigue_performance_correlation is not null
    or v_analysis.overall_time_performance_correlation is not null
    or v_analysis.overall_fatigue_performance_correlation is not null
    or v_analysis.is_pareto_optimal is distinct from false
  then
    raise exception 'seven-sample variance gate mismatch: %',
      row_to_json(v_analysis);
  end if;
end;
$contract$;
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001233',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $contract$
declare
  v_analysis record;
  v_count bigint;
begin
  select count(*) into v_count from public.daily_habits;
  if v_count is distinct from 1::bigint then
    raise exception 'tenant A habit visibility mismatch: %', v_count;
  end if;
  select count(*) into v_count from public.daily_habit_logs;
  if v_count is distinct from 7::bigint then
    raise exception 'tenant A log visibility mismatch: %', v_count;
  end if;

  update public.daily_habit_logs
  set goal_contribution_measurement_source =
    'self_reported_goal_contribution_proxy'
  where habit_id = '00000000-0000-4000-8000-000000112331'
    and completed_date = current_date - 7;

  select * into v_analysis
  from public.analyze_habit_resource_efficiency(90);
  if not found
    or v_analysis.sample_count is distinct from 7::bigint
    or v_analysis.has_sufficient_data is distinct from true
    or v_analysis.insufficient_data_reason is not null
    or v_analysis.performance_sample_stddev is null
    or v_analysis.time_performance_correlation is null
    or v_analysis.fatigue_performance_correlation is null
    or v_analysis.overall_time_performance_correlation is null
    or v_analysis.overall_fatigue_performance_correlation is null
    or v_analysis.is_pareto_optimal is distinct from true
  then
    raise exception 'seven self-reports did not enable analysis: %',
      row_to_json(v_analysis);
  end if;
end;
$contract$;
reset role;

-- PUBLIC/anon have no RPC execution even if they try an actual call.
set local role anon;
do $contract$
begin
  begin
    perform * from public.analyze_habit_resource_efficiency(90);
    raise exception 'anon analysis RPC call was accepted';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform * from public.consume_resource_optimizer_ai_quota();
    raise exception 'anon quota RPC call was accepted';
  exception when insufficient_privilege then
    null;
  end;
end;
$contract$;
reset role;

-- Per-user cooldown and non-interference use real authenticated RPC calls.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001233',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
do $contract$
declare
  v_result record;
  v_count integer;
begin
  select * into v_result
  from public.consume_resource_optimizer_ai_quota();
  if v_result.allowed is distinct from true
    or v_result.reason is distinct from 'allowed'
    or v_result.remaining_daily is distinct from 9
  then
    raise exception 'initial quota result mismatch: %', row_to_json(v_result);
  end if;

  select * into v_result
  from public.consume_resource_optimizer_ai_quota();
  if v_result.allowed is distinct from false
    or v_result.reason is distinct from 'cooldown'
    or v_result.remaining_daily is distinct from 9
    or v_result.retry_after_seconds not between 1 and 60
  then
    raise exception 'cooldown result mismatch: %', row_to_json(v_result);
  end if;

  select request_count into v_count
  from public.resource_optimizer_ai_quota;
  if v_count is distinct from 1 then
    raise exception 'cooldown consumed quota: %', v_count;
  end if;
end;
$contract$;
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001234',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
do $contract$
declare
  v_result record;
  v_count bigint;
begin
  select * into v_result
  from public.consume_resource_optimizer_ai_quota();
  if v_result.allowed is distinct from true
    or v_result.remaining_daily is distinct from 9
  then
    raise exception 'other-user quota was blocked: %', row_to_json(v_result);
  end if;

  select count(*) into v_count
  from public.resource_optimizer_ai_quota;
  if v_count is distinct from 1::bigint then
    raise exception 'quota RLS exposed another user: %', v_count;
  end if;

  update public.resource_optimizer_ai_quota
  set request_count = request_count + 1,
      last_requested_at = pg_catalog.clock_timestamp()
  where user_id = '00000000-0000-4000-8000-000000001233';
  if found then
    raise exception 'quota RLS updated another user';
  end if;
end;
$contract$;
reset role;

-- Seed a near-limit row as the trusted fixture owner, then prove the tenth
-- consume is atomic and an eleventh call cannot cross the daily cap.
alter table public.resource_optimizer_ai_quota
  disable trigger validate_resource_optimizer_ai_quota_write;
insert into public.resource_optimizer_ai_quota (
  user_id,
  usage_date,
  request_count,
  last_requested_at
)
values (
  '00000000-0000-4000-8000-000000001237',
  (pg_catalog.timezone('UTC', pg_catalog.clock_timestamp()))::date,
  9,
  pg_catalog.clock_timestamp() - interval '2 minutes'
);
alter table public.resource_optimizer_ai_quota
  enable trigger validate_resource_optimizer_ai_quota_write;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000001237',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
do $contract$
declare
  v_result record;
  v_count integer;
begin
  select * into v_result
  from public.consume_resource_optimizer_ai_quota();
  if v_result.allowed is distinct from true
    or v_result.remaining_daily is distinct from 0
  then
    raise exception 'tenth daily quota result mismatch: %', row_to_json(v_result);
  end if;

  select * into v_result
  from public.consume_resource_optimizer_ai_quota();
  if v_result.allowed is distinct from false
    or v_result.reason is distinct from 'daily_limit'
    or v_result.remaining_daily is distinct from 0
    or v_result.retry_after_seconds is distinct from 0
  then
    raise exception 'daily limit result mismatch: %', row_to_json(v_result);
  end if;

  select request_count into v_count
  from public.resource_optimizer_ai_quota;
  if v_count is distinct from 10 then
    raise exception 'daily limit changed quota count: %', v_count;
  end if;
end;
$contract$;
reset role;

-- The Python runner races two independent PostgreSQL connections at count 9
-- and asserts exactly one reaches the daily limit.
alter table public.resource_optimizer_ai_quota
  disable trigger validate_resource_optimizer_ai_quota_write;
delete from public.resource_optimizer_ai_quota
where user_id = '00000000-0000-4000-8000-000000001235';
insert into public.resource_optimizer_ai_quota (
  user_id,
  usage_date,
  request_count,
  last_requested_at
)
values (
  '00000000-0000-4000-8000-000000001235',
  (pg_catalog.timezone('UTC', pg_catalog.clock_timestamp()))::date,
  9,
  pg_catalog.clock_timestamp() - interval '2 minutes'
);
alter table public.resource_optimizer_ai_quota
  enable trigger validate_resource_optimizer_ai_quota_write;
