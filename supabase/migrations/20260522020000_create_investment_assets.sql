-- Asset management phase 2B: investment asset schema.
-- Issue #2465. This migration adds storage only; price fetch, UI, and
-- production sync behavior stay in later scoped issues.

begin;

create table if not exists public.investment_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  asset_type text not null,
  ticker text not null,
  quantity numeric(28, 8) not null,
  buy_price_jpy numeric(20, 4) not null default 0,
  buy_date date,
  current_price_jpy numeric(20, 4),
  last_priced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint investment_assets_asset_type_check
    check (asset_type in ('stock', 'crypto', 'reit', 'etf')),
  constraint investment_assets_ticker_not_blank
    check (length(btrim(ticker)) > 0),
  constraint investment_assets_quantity_positive
    check (quantity > 0),
  constraint investment_assets_buy_price_non_negative
    check (buy_price_jpy >= 0),
  constraint investment_assets_current_price_non_negative
    check (current_price_jpy is null or current_price_jpy >= 0),
  constraint investment_assets_last_price_requires_price
    check (last_priced_at is null or current_price_jpy is not null)
);

create index if not exists investment_assets_user_type_ticker_idx
  on public.investment_assets (user_id, asset_type, ticker);

create index if not exists investment_assets_user_last_priced_idx
  on public.investment_assets (user_id, last_priced_at desc nulls last);

comment on table public.investment_assets is
  'Asset management phase 2B investment holdings for stocks, crypto, REITs, and ETFs. Issue #2465.';
comment on column public.investment_assets.quantity is
  'Decimal quantity so fractional shares and crypto holdings can be stored deterministically.';
comment on column public.investment_assets.current_price_jpy is
  'Latest cached JPY unit price. Populated by later market-price fetch work; nullable until priced.';

alter table public.investment_assets enable row level security;

drop policy if exists investment_assets_select_own
  on public.investment_assets;
create policy investment_assets_select_own
on public.investment_assets
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists investment_assets_insert_own
  on public.investment_assets;
create policy investment_assets_insert_own
on public.investment_assets
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists investment_assets_update_own
  on public.investment_assets;
create policy investment_assets_update_own
on public.investment_assets
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists investment_assets_delete_own
  on public.investment_assets;
create policy investment_assets_delete_own
on public.investment_assets
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.set_investment_assets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists investment_assets_updated_at
  on public.investment_assets;
create trigger investment_assets_updated_at
before update on public.investment_assets
for each row execute function public.set_investment_assets_updated_at();

commit;
