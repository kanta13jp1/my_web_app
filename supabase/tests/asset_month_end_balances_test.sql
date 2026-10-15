-- Executable contract tests against an isolated Postgres instance.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into public.asset_month_end_snapshot_settings(user_id, enabled) values
 ('00000000-0000-0000-0000-000000000001', true),
 ('00000000-0000-0000-0000-000000000002', false);
insert into public.cfo_assets(user_id,title,amount,created_at) values
 ('00000000-0000-0000-0000-000000000001','bank',1000,'2026-08-30T12:00:00Z'),
 ('00000000-0000-0000-0000-000000000001','bank',1200,'2026-08-31T14:59:59Z'),
 ('00000000-0000-0000-0000-000000000001','bank',9900,'2026-08-31T15:00:00Z'),
 ('00000000-0000-0000-0000-000000000001','loan',-4000,'2026-07-31T14:00:00Z'),
 ('00000000-0000-0000-0000-000000000002','bank',5000,'2026-08-30T12:00:00Z'),
 ('00000000-0000-0000-0000-000000000003','bank',5000,'2026-08-30T12:00:00Z');
do $test$
declare r public.asset_month_end_balance_snapshots;
begin
 assert asset_snapshot_private.capture_month_end_balances('2026-08-31T14:59:59Z') = 0,
   'must not capture before JST rollover';
 assert asset_snapshot_private.capture_month_end_balances('2026-08-31T15:05:00Z') = 1,
   'only enabled user should capture';
 select * into strict r from public.asset_month_end_balance_snapshots;
 assert r.month_key = '2026-08-01'::date;
 assert r.total_assets = 1200 and r.total_liabilities = -4000 and r.net_worth = -2800,
   'boundary must exclude next month and use most recent observation';
 assert r.stale_account_count = 1, 'old loan observation must remain visible';
 assert jsonb_array_length(r.accounts) = 2;
 assert r.accounts @> '[{"title":"loan","stale":true}]';
 assert asset_snapshot_private.capture_month_end_balances('2026-08-31T16:05:00Z') = 0,
   'retry must not duplicate or overwrite checkpoint';
 assert not has_function_privilege('authenticated',
   'asset_snapshot_private.capture_month_end_balances(timestamptz)', 'execute');
 assert not has_table_privilege('authenticated','public.asset_month_end_balance_snapshots','update');
end;
$test$;
-- A later edit cannot change an already saved checkpoint.
insert into public.cfo_assets(user_id,title,amount,created_at) values
 ('00000000-0000-0000-0000-000000000001','bank',3000,'2026-08-31T14:59:59.9Z');
select asset_snapshot_private.capture_month_end_balances('2026-08-31T17:05:00Z');
do $test$ begin
 assert (select total_assets from public.asset_month_end_balance_snapshots) = 1200;
 -- December/January rollover uses the previous year.
 assert asset_snapshot_private.capture_month_end_balances('2026-12-31T15:05:00Z') = 1;
 assert exists(select 1 from public.asset_month_end_balance_snapshots where month_key='2026-12-01');
end; $test$;
-- Prove owner isolation and no automatic opt-in.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $test$ begin
 assert (select count(*) from public.asset_month_end_balance_snapshots) = 0;
 assert (select count(*) from public.asset_month_end_snapshot_settings) = 1;
end; $test$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $test$ begin
 assert (select count(*) from public.asset_month_end_balance_snapshots) = 2;
end; $test$;
reset role;
rollback;
