-- Issue #2489: owner-scoped tax records for asset-management tax workflows.
-- This migration adds persistence only. Calculators, tracking UI, exports,
-- and invoice workflows remain in their separately scoped follow-up issues.

begin;

create table if not exists public.tax_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  year smallint not null,
  type text not null,
  amount numeric(20, 4) not null,
  category text not null,
  evidence_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tax_records_year_valid
    check (year between 1900 and 9999),
  constraint tax_records_type_valid
    check (type in ('furusato', 'medical', 'business', 'realestate', 'other')),
  constraint tax_records_amount_non_negative
    check (amount >= 0),
  constraint tax_records_category_length
    check (length(btrim(category)) between 1 and 200),
  constraint tax_records_evidence_url_length
    check (
      evidence_url is null
      or length(btrim(evidence_url)) between 1 and 2048
    )
);

create index if not exists tax_records_user_year_type_idx
  on public.tax_records (user_id, year desc, type, id);

comment on table public.tax_records is
  'Per-user tax records for furusato, medical, business, real-estate, and other tax workflows. Issue #2489.';
comment on column public.tax_records.year is
  'Japanese tax year used for deterministic filtering and later export.';
comment on column public.tax_records.amount is
  'Non-negative exact amount. Tax treatment and totals are calculated deterministically outside AI.';
comment on column public.tax_records.category is
  'User-facing category within the constrained tax record type.';
comment on column public.tax_records.evidence_url is
  'Optional evidence locator. It can contain sensitive data and is protected by owner-only RLS.';

alter table public.tax_records enable row level security;

-- RLS does not protect TRUNCATE, REFERENCES, or TRIGGER. Remove inherited
-- privileges and expose only policy-backed CRUD to authenticated clients.
revoke all privileges on table public.tax_records
from public, anon, authenticated;

grant all privileges on table public.tax_records to service_role;
grant select, insert, update, delete on table public.tax_records
to authenticated;

drop policy if exists tax_records_select_own on public.tax_records;
create policy tax_records_select_own
  on public.tax_records
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tax_records_insert_own on public.tax_records;
create policy tax_records_insert_own
  on public.tax_records
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists tax_records_update_own on public.tax_records;
create policy tax_records_update_own
  on public.tax_records
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tax_records_delete_own on public.tax_records;
create policy tax_records_delete_own
  on public.tax_records
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.set_tax_records_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tax_records_updated_at on public.tax_records;
create trigger tax_records_updated_at
before update on public.tax_records
for each row execute function public.set_tax_records_updated_at();

commit;
