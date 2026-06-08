-- Asset management phase 2B: market price cache.
-- Issue #2466. External market data fetches are opt-in at the Edge Function;
-- this table stores the deterministic cache used by investment_assets pricing.

begin;

create table if not exists public.investment_market_price_cache (
  id uuid primary key default gen_random_uuid(),
  asset_type text not null,
  ticker text not null,
  currency text not null default 'JPY',
  provider text not null,
  price_jpy numeric(20, 4) not null,
  fetched_at timestamptz not null,
  expires_at timestamptz not null,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint investment_market_price_cache_asset_type_check
    check (asset_type in ('stock', 'crypto', 'reit', 'etf')),
  constraint investment_market_price_cache_ticker_not_blank
    check (length(btrim(ticker)) > 0),
  constraint investment_market_price_cache_currency_not_blank
    check (length(btrim(currency)) > 0),
  constraint investment_market_price_cache_provider_not_blank
    check (length(btrim(provider)) > 0),
  constraint investment_market_price_cache_price_non_negative
    check (price_jpy >= 0),
  constraint investment_market_price_cache_expires_after_fetch
    check (expires_at > fetched_at),
  constraint investment_market_price_cache_unique_key
    unique (asset_type, ticker, currency)
);

create index if not exists investment_market_price_cache_freshness_idx
  on public.investment_market_price_cache (asset_type, ticker, currency, expires_at desc);

comment on table public.investment_market_price_cache is
  'Cache for opt-in investment market price fetches. Issue #2466.';
comment on column public.investment_market_price_cache.price_jpy is
  'Cached unit price in JPY. External fetches are feature-flagged off by default.';
comment on column public.investment_market_price_cache.expires_at is
  'Default cache expiry is 30 minutes after fetched_at; stale rows are used only as graceful fallback.';

alter table public.investment_market_price_cache enable row level security;

drop policy if exists investment_market_price_cache_service_role_all
  on public.investment_market_price_cache;
create policy investment_market_price_cache_service_role_all
on public.investment_market_price_cache
for all
to service_role
using (true)
with check (true);

create or replace function public.set_investment_market_price_cache_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists investment_market_price_cache_updated_at
  on public.investment_market_price_cache;
create trigger investment_market_price_cache_updated_at
before update on public.investment_market_price_cache
for each row execute function public.set_investment_market_price_cache_updated_at();

commit;
