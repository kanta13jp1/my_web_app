-- Server-side month-end checkpoints. No historical backfill or activation.
-- Separate from editable manual snapshots: do not change their semantics.
create schema if not exists asset_snapshot_private;
revoke all on schema asset_snapshot_private from public, anon, authenticated;

create table public.asset_month_end_snapshot_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false
);
alter table public.asset_month_end_snapshot_settings enable row level security;
create policy month_end_settings_owner on public.asset_month_end_snapshot_settings
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
revoke all on public.asset_month_end_snapshot_settings from public, anon, authenticated;
grant select, insert, update, delete on public.asset_month_end_snapshot_settings to authenticated;

create table public.asset_month_end_balance_snapshots (
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key date not null check (extract(day from month_key) = 1),
  cutoff_at timestamptz not null,
  captured_at timestamptz not null,
  total_assets numeric not null check (total_assets >= 0),
  total_liabilities numeric not null check (total_liabilities <= 0),
  net_worth numeric not null,
  accounts jsonb not null check (jsonb_typeof(accounts) = 'array'),
  stale_account_count integer not null check (stale_account_count >= 0),
  undated_account_count integer not null check (undated_account_count >= 0),
  -- The source is recorded balances, never a bank-confirmed month-end statement.
  source text not null default 'recorded_balances' check (source = 'recorded_balances'),
  primary key (user_id, month_key),
  check (net_worth = total_assets + total_liabilities)
);
alter table public.asset_month_end_balance_snapshots enable row level security;
create policy month_end_snapshots_owner_read on public.asset_month_end_balance_snapshots
  for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.asset_month_end_balance_snapshots from public, anon, authenticated;
grant select on public.asset_month_end_balance_snapshots to authenticated;

-- Supports each opted-in user's latest observation per account at the boundary.
create index if not exists cfo_assets_month_end_lookup_idx
  on public.cfo_assets (user_id, title, created_at desc, id desc);

create or replace function asset_snapshot_private.capture_month_end_balances(
  p_run_at timestamptz default now()
) returns integer
language plpgsql security definer set search_path = '' as $function$
declare
  v_cutoff timestamptz;
  v_month date;
  v_inserted integer;
begin
  -- UTC 15:05 daily runs are a retry window, but only JST day 1 captures.
  -- No arbitrary backfill: missing older months remain visibly missing.
  if extract(day from p_run_at at time zone 'Asia/Tokyo') <> 1 then
    return 0;
  end if;
  v_cutoff := date_trunc('month', p_run_at at time zone 'Asia/Tokyo')
    at time zone 'Asia/Tokyo';
  v_month := (v_cutoff at time zone 'Asia/Tokyo' - interval '1 month')::date;
  with latest as (
    select distinct on (a.user_id, a.title)
      a.user_id, a.title, a.amount, a.created_at, a.id
    from public.cfo_assets a
    join public.asset_month_end_snapshot_settings s on s.user_id = a.user_id and s.enabled
    where a.created_at < v_cutoff
      and a.amount is not null and a.title is not null
    order by a.user_id, a.title, a.created_at desc, a.id desc
  ), totals as (
    select user_id,
      coalesce(sum(amount) filter (where amount > 0), 0) as assets,
      coalesce(sum(amount) filter (where amount < 0), 0) as liabilities,
      sum(amount) as net,
      jsonb_agg(jsonb_build_object(
        'title', title, 'amount', amount, 'observed_at', created_at,
        'stale', created_at < v_month::timestamp at time zone 'Asia/Tokyo'
      ) order by title) as accounts,
      count(*) filter (where created_at < v_month::timestamp at time zone 'Asia/Tokyo')::integer as stale
    from latest group by user_id
  ), undated as (
    select a.user_id, count(distinct a.title)::integer as count
    from public.cfo_assets a
    join public.asset_month_end_snapshot_settings s on s.user_id = a.user_id and s.enabled
    where a.created_at is null
    group by a.user_id
  )
  insert into public.asset_month_end_balance_snapshots (
    user_id, month_key, cutoff_at, captured_at, total_assets,
    total_liabilities, net_worth, accounts, stale_account_count, undated_account_count
  ) select t.user_id, v_month, v_cutoff, p_run_at, assets, liabilities, net,
      accounts, stale, coalesce(u.count, 0)
    from totals t left join undated u on u.user_id = t.user_id
  on conflict (user_id, month_key) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;
revoke all on function asset_snapshot_private.capture_month_end_balances(timestamptz)
  from public, anon, authenticated;

-- Capture is opt-in, independent of browser state, and never calls an LLM.
-- Reusing a named job prevents duplicate schedules on repeat setup.
do $setup$
begin
  if to_regprocedure('cron.schedule(text,text,text)') is not null then
    perform cron.schedule('asset-month-end-balances', '5,35 15 * * *',
      'select asset_snapshot_private.capture_month_end_balances();');
  else
    raise notice 'Month-end capture job not installed: pg_cron must be enabled before activation';
  end if;
end;
$setup$;
