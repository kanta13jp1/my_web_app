-- Issue #2496: owner-scoped MoneyForward account and transaction snapshots.
--
-- Provider credentials deliberately do not live in these tables. A later
-- server-only sync must resolve encrypted credentials and write snapshots with
-- the service role; authenticated clients can only read their own rows.

begin;

create table if not exists public.mf_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mf_account_id text not null,
  account_name text not null,
  account_type text not null,
  balance_jpy numeric(20, 4) not null,
  last_synced_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mf_accounts_provider_id_length
    check (length(btrim(mf_account_id)) between 1 and 256),
  constraint mf_accounts_name_length
    check (length(btrim(account_name)) between 1 and 200),
  constraint mf_accounts_type_length
    check (length(btrim(account_type)) between 1 and 100),
  constraint mf_accounts_user_provider_unique
    unique (user_id, mf_account_id)
);

create table if not exists public.mf_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mf_account_id text not null,
  mf_transaction_id text not null,
  transaction_date date not null,
  amount numeric(20, 4) not null,
  category text not null default '',
  description text not null default '',
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mf_transactions_account_id_length
    check (length(btrim(mf_account_id)) between 1 and 256),
  constraint mf_transactions_provider_id_length
    check (length(btrim(mf_transaction_id)) between 1 and 256),
  constraint mf_transactions_category_length
    check (length(category) <= 200),
  constraint mf_transactions_description_length
    check (length(description) <= 2000),
  constraint mf_transactions_raw_payload_object
    check (jsonb_typeof(raw_payload) = 'object'),
  constraint mf_transactions_user_provider_unique
    unique (user_id, mf_transaction_id),
  constraint mf_transactions_account_owner_fkey
    foreign key (user_id, mf_account_id)
    references public.mf_accounts (user_id, mf_account_id)
    on delete cascade
);

create index if not exists mf_accounts_user_last_synced_idx
  on public.mf_accounts (user_id, last_synced_at desc);

create index if not exists mf_transactions_user_date_idx
  on public.mf_transactions (user_id, transaction_date desc);

create index if not exists mf_transactions_user_account_date_idx
  on public.mf_transactions (user_id, mf_account_id, transaction_date desc);

comment on table public.mf_accounts is
  'Per-user MoneyForward account snapshots written by a service-role sync. Issue #2496.';
comment on column public.mf_accounts.mf_account_id is
  'Stable provider account identifier, unique within a user.';
comment on column public.mf_accounts.balance_jpy is
  'Exact provider-reported JPY balance; negative balances are valid.';
comment on table public.mf_transactions is
  'Per-user MoneyForward transaction snapshots written by a service-role sync. Issue #2496.';
comment on column public.mf_transactions.mf_transaction_id is
  'Stable provider transaction identifier used for idempotent upserts.';
comment on column public.mf_transactions.raw_payload is
  'Sensitive provider payload. Owner-readable and never writable by authenticated clients.';

alter table public.mf_accounts enable row level security;
alter table public.mf_transactions enable row level security;

revoke all privileges on table public.mf_accounts, public.mf_transactions
from public, anon, authenticated;

grant all privileges on table public.mf_accounts, public.mf_transactions
to service_role;

grant select on table public.mf_accounts, public.mf_transactions
to authenticated;

drop policy if exists mf_accounts_select_own on public.mf_accounts;
create policy mf_accounts_select_own
  on public.mf_accounts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists mf_transactions_select_own on public.mf_transactions;
create policy mf_transactions_select_own
  on public.mf_transactions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.set_mf_accounts_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_mf_transactions_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists mf_accounts_updated_at on public.mf_accounts;
create trigger mf_accounts_updated_at
before update on public.mf_accounts
for each row execute function public.set_mf_accounts_updated_at();

drop trigger if exists mf_transactions_updated_at on public.mf_transactions;
create trigger mf_transactions_updated_at
before update on public.mf_transactions
for each row execute function public.set_mf_transactions_updated_at();

commit;
