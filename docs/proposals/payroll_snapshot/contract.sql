-- Disposable database ONLY. Never run against the application database.
\set ON_ERROR_STOP on
do $guard$ begin
  if current_database() <> 'payroll_contract' then
    raise exception 'Disposable payroll_contract database required';
  end if;
end $guard$;
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
insert into auth.users values
  ('aaaaaaaa-0000-0000-0000-000000000001'),
  ('bbbbbbbb-0000-0000-0000-000000000002');
\i DRAFT_PAYROLL_SCHEMA.sql

create function public.test_assert(p_pass boolean, p_message text) returns void
language plpgsql security invoker as $test$ begin
  if p_pass is distinct from true then raise exception 'FAIL: %', p_message; end if;
end $test$;
create function public.test_error(p_sql text, p_state text) returns void
language plpgsql security invoker as $test$
declare v_state text;
begin
  begin
    execute p_sql;
    raise exception 'Expected failure did not occur';
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    if v_state <> p_state then
      raise exception 'Expected %, got % for %', p_state, v_state, p_sql;
    end if;
  end;
end $test$;
create function public.test_save(p_request integer, p_balance bigint,
  p_previous uuid default null, p_confirm boolean default true) returns uuid
language sql security invoker as $test$
  select public.confirm_payroll_balance_observation(
    'aaaaaaaa-1111-1111-1111-111111111111', '2030-02-01', 'synthetic-deposit',
    '2030-02-20', 'day', null, null, p_balance, 'synthetic owner-confirmed row',
    ('00000000-0000-0000-0000-' || lpad(p_request::text, 12, '0'))::uuid,
    p_previous, 'synthetic confirmation', p_confirm
  );
$test$;

set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', false);
insert into public.asset_payroll_accounts(user_id, id, display_label) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-1111-1111-1111-111111111111', 'Synthetic payroll account');
do $test$
declare first_id uuid; correction_id uuid;
begin
  first_id := public.test_save(1, 500);
  perform public.test_assert(first_id = public.test_save(1, 500), 'same request returns same observation');
  perform public.test_assert((select count(*) = 1 from public.asset_payroll_balance_observations), 'retry has one observation');
  perform public.test_assert((select count(*) = 1 from public.asset_payroll_balance_selection_history), 'retry has one audit row');
  perform public.test_error('select public.test_save(1, 501)', '22023');
  perform public.test_error('select public.test_save(8, 500, null, false)', '42501');
  correction_id := public.test_save(2, 550, first_id);
  perform public.test_assert((select observation_id = correction_id from public.asset_payroll_balance_selections), 'correction selected');
  perform public.test_assert((select count(*) = 2 from public.asset_payroll_balance_selection_history), 'correction audited');
  perform public.test_assert(public.test_save(1, 500) = first_id, 'old retry remains idempotent');
  perform public.test_assert((select observation_id = correction_id from public.asset_payroll_balance_selections), 'old retry does not roll back selection');
  perform public.test_error(format('select public.test_save(3, 560, %L)', first_id), '40001');
  perform public.test_assert((select count(*) = 2 from public.asset_payroll_balance_observations), 'stale correction rolled back atomically');
end $test$;
select public.test_error('update public.asset_payroll_balance_observations set balance_yen = 1', '42501');
select public.test_error('delete from public.asset_payroll_balance_observations', '42501');
select public.test_error('insert into public.asset_payroll_balance_selection_history(user_id,account_id,payroll_month,new_observation_id,reason) select user_id,account_id,payroll_month,observation_id,reason from public.asset_payroll_balance_selections', '42501');
select public.test_error('update public.asset_payroll_accounts set user_id = ''bbbbbbbb-0000-0000-0000-000000000002''', '42501');
select public.test_error('insert into public.asset_payroll_accounts(user_id,id,display_label) values (''bbbbbbbb-0000-0000-0000-000000000002'',''bbbbbbbb-1111-1111-1111-111111111111'',''forged'')', '42501');

-- A client cannot assert bank-verified evidence or set the server capture time.
select public.test_error('insert into public.asset_payroll_balance_observations(user_id,account_id,payroll_month,deposit_reference,deposit_date,date_precision,balance_yen,evidence_kind,source_note,confirmation_version,selection_reason,request_id) values (''aaaaaaaa-0000-0000-0000-000000000001'',''aaaaaaaa-1111-1111-1111-111111111111'',''2030-02-01'',''synthetic'',''2030-02-20'',''day'',500,''bank_verified'',''synthetic'',''immediate-balance-v1'',''synthetic'',''00000000-0000-0000-0000-000000000009'')', '23514');
select public.test_error('insert into public.asset_payroll_balance_observations(recorded_at) values (now())', '42501');

select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000002', false);
select public.test_assert((select count(*) = 0 from public.asset_payroll_accounts), 'foreign accounts hidden');
select public.test_assert((select count(*) = 0 from public.asset_payroll_balance_observations), 'foreign observations hidden');
select public.test_assert((select count(*) = 0 from public.asset_payroll_balance_selections), 'foreign selections hidden');
select public.test_assert((select count(*) = 0 from public.asset_payroll_balance_selection_history), 'foreign audit hidden');
select public.test_error('select public.test_save(5, 700)', '42501');
reset role;
set role anon;
select public.test_error('select * from public.asset_payroll_accounts', '42501');
select public.test_error('select * from public.asset_payroll_balance_observations', '42501');
select public.test_error('select * from public.asset_payroll_balance_selections', '42501');
select public.test_error('select * from public.asset_payroll_balance_selection_history', '42501');
select public.test_error('select public.test_save(6, 800)', '42501');
reset role;
select 'PASS: payroll schema owner/RLS/retry/correction contract';
