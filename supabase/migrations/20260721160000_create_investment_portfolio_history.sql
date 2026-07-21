-- Asset management phase 2B: deterministic daily portfolio history.
-- Issue #2469. Snapshots are maintained by investment_assets triggers so
-- chart history does not depend on client clocks or AI-generated values.

begin;

create table if not exists public.investment_portfolio_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recorded_on date not null default current_date,
  recorded_at timestamptz not null default now(),
  market_value_jpy numeric(28, 4) not null default 0,
  acquisition_cost_jpy numeric(28, 4) not null default 0,
  priced_asset_count integer not null default 0,
  unpriced_asset_count integer not null default 0,
  constraint investment_portfolio_history_market_value_non_negative
    check (market_value_jpy >= 0),
  constraint investment_portfolio_history_acquisition_cost_non_negative
    check (acquisition_cost_jpy >= 0),
  constraint investment_portfolio_history_priced_count_non_negative
    check (priced_asset_count >= 0),
  constraint investment_portfolio_history_unpriced_count_non_negative
    check (unpriced_asset_count >= 0),
  constraint investment_portfolio_history_user_day_unique
    unique (user_id, recorded_on)
);

create index if not exists investment_portfolio_history_user_recorded_idx
  on public.investment_portfolio_history (user_id, recorded_at desc);

comment on table public.investment_portfolio_history is
  'Daily deterministic investment portfolio valuation snapshots for Issue #2469.';
comment on column public.investment_portfolio_history.acquisition_cost_jpy is
  'Acquisition cost for priced holdings only, aligned with market_value_jpy.';

alter table public.investment_portfolio_history enable row level security;

drop policy if exists investment_portfolio_history_select_own
  on public.investment_portfolio_history;
create policy investment_portfolio_history_select_own
on public.investment_portfolio_history
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.capture_investment_portfolio_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
begin
  target_user_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;

  if not exists (select 1 from auth.users where id = target_user_id) then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  insert into public.investment_portfolio_history (
    user_id,
    recorded_on,
    recorded_at,
    market_value_jpy,
    acquisition_cost_jpy,
    priced_asset_count,
    unpriced_asset_count
  )
  select
    target_user_id,
    current_date,
    now(),
    coalesce(sum(quantity * current_price_jpy)
      filter (where current_price_jpy is not null), 0),
    coalesce(sum(quantity * buy_price_jpy)
      filter (where current_price_jpy is not null), 0),
    (count(*) filter (where current_price_jpy is not null))::integer,
    (count(*) filter (where current_price_jpy is null))::integer
  from public.investment_assets
  where user_id = target_user_id
  on conflict (user_id, recorded_on) do update
  set recorded_at = excluded.recorded_at,
      market_value_jpy = excluded.market_value_jpy,
      acquisition_cost_jpy = excluded.acquisition_cost_jpy,
      priced_asset_count = excluded.priced_asset_count,
      unpriced_asset_count = excluded.unpriced_asset_count;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists investment_assets_history_after_insert
  on public.investment_assets;
create trigger investment_assets_history_after_insert
after insert on public.investment_assets
for each row execute function public.capture_investment_portfolio_history();

drop trigger if exists investment_assets_history_after_update
  on public.investment_assets;
create trigger investment_assets_history_after_update
after update of quantity, buy_price_jpy, current_price_jpy
on public.investment_assets
for each row execute function public.capture_investment_portfolio_history();

drop trigger if exists investment_assets_history_after_delete
  on public.investment_assets;
create trigger investment_assets_history_after_delete
after delete on public.investment_assets
for each row execute function public.capture_investment_portfolio_history();

insert into public.investment_portfolio_history (
  user_id,
  recorded_on,
  recorded_at,
  market_value_jpy,
  acquisition_cost_jpy,
  priced_asset_count,
  unpriced_asset_count
)
select
  user_id,
  current_date,
  now(),
  coalesce(sum(quantity * current_price_jpy)
    filter (where current_price_jpy is not null), 0),
  coalesce(sum(quantity * buy_price_jpy)
    filter (where current_price_jpy is not null), 0),
  (count(*) filter (where current_price_jpy is not null))::integer,
  (count(*) filter (where current_price_jpy is null))::integer
from public.investment_assets
group by user_id
on conflict (user_id, recorded_on) do nothing;

commit;
