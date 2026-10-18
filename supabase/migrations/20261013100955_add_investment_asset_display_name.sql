-- Optional label only: ticker remains the market-price and import identifier.
alter table public.investment_assets
  add column if not exists display_name text;

comment on column public.investment_assets.display_name is
  'Optional user-editable investment name. Null keeps the ticker-only display.';
