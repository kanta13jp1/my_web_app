-- Asset/liability board Supabase schema foundation.
--
-- Scope:
-- - Creates persistence tables and owner-only RLS policies.
-- - Does not enable application production writes.
-- - SharedPreferences remains the primary runtime store until a later adapter PR.
--
-- Migration plan from SharedPreferences:
-- 1. Initial sync: after authentication, load the local repository snapshot and
--    upsert one payload row per user/month/table.
-- 2. Conflict priority: compare updated_at; the newer row wins by default.
--    If the remote row is newer than local unsynced edits, prompt before
--    overwriting.
-- 3. Device sync: refresh remote rows by user_id/month_key before saving, then
--    upsert through the repository layer. UI must not call Supabase directly.
-- 4. Rollback: keep the SharedPreferences adapter available behind the same
--    repository interface. If Supabase writes are disabled, local data remains
--    authoritative and these tables can stay unused.

create or replace function public.set_asset_liability_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.asset_liability_monthly_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_liability_monthly_states_month_key_format
    check (month_key = 'global' or month_key ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint asset_liability_monthly_states_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint asset_liability_monthly_states_user_month_unique
    unique (user_id, month_key)
);

create table if not exists public.asset_liability_income_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_liability_income_plans_month_key_format
    check (month_key = 'global' or month_key ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint asset_liability_income_plans_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint asset_liability_income_plans_user_month_unique
    unique (user_id, month_key)
);

create table if not exists public.asset_liability_recurring_income_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null default 'global',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_liability_recurring_income_templates_month_key_format
    check (month_key = 'global' or month_key ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint asset_liability_recurring_income_templates_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint asset_liability_recurring_income_templates_user_month_unique
    unique (user_id, month_key)
);

create table if not exists public.asset_liability_payment_source_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_liability_payment_source_settings_month_key_format
    check (month_key = 'global' or month_key ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint asset_liability_payment_source_settings_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint asset_liability_payment_source_settings_user_month_unique
    unique (user_id, month_key)
);

create table if not exists public.asset_liability_monthly_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_liability_monthly_snapshots_month_key_format
    check (month_key = 'global' or month_key ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint asset_liability_monthly_snapshots_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint asset_liability_monthly_snapshots_user_month_unique
    unique (user_id, month_key)
);

create index if not exists asset_liability_monthly_states_user_month_idx
  on public.asset_liability_monthly_states (user_id, month_key);
create index if not exists asset_liability_monthly_states_payload_gin_idx
  on public.asset_liability_monthly_states using gin (payload);

create index if not exists asset_liability_income_plans_user_month_idx
  on public.asset_liability_income_plans (user_id, month_key);
create index if not exists asset_liability_income_plans_payload_gin_idx
  on public.asset_liability_income_plans using gin (payload);

create index if not exists asset_liability_recurring_income_templates_user_month_idx
  on public.asset_liability_recurring_income_templates (user_id, month_key);
create index if not exists asset_liability_recurring_income_templates_payload_gin_idx
  on public.asset_liability_recurring_income_templates using gin (payload);

create index if not exists asset_liability_payment_source_settings_user_month_idx
  on public.asset_liability_payment_source_settings (user_id, month_key);
create index if not exists asset_liability_payment_source_settings_payload_gin_idx
  on public.asset_liability_payment_source_settings using gin (payload);

create index if not exists asset_liability_monthly_snapshots_user_month_idx
  on public.asset_liability_monthly_snapshots (user_id, month_key);
create index if not exists asset_liability_monthly_snapshots_payload_gin_idx
  on public.asset_liability_monthly_snapshots using gin (payload);

drop trigger if exists asset_liability_monthly_states_updated_at
  on public.asset_liability_monthly_states;
create trigger asset_liability_monthly_states_updated_at
before update on public.asset_liability_monthly_states
for each row execute function public.set_asset_liability_updated_at();

drop trigger if exists asset_liability_income_plans_updated_at
  on public.asset_liability_income_plans;
create trigger asset_liability_income_plans_updated_at
before update on public.asset_liability_income_plans
for each row execute function public.set_asset_liability_updated_at();

drop trigger if exists asset_liability_recurring_income_templates_updated_at
  on public.asset_liability_recurring_income_templates;
create trigger asset_liability_recurring_income_templates_updated_at
before update on public.asset_liability_recurring_income_templates
for each row execute function public.set_asset_liability_updated_at();

drop trigger if exists asset_liability_payment_source_settings_updated_at
  on public.asset_liability_payment_source_settings;
create trigger asset_liability_payment_source_settings_updated_at
before update on public.asset_liability_payment_source_settings
for each row execute function public.set_asset_liability_updated_at();

drop trigger if exists asset_liability_monthly_snapshots_updated_at
  on public.asset_liability_monthly_snapshots;
create trigger asset_liability_monthly_snapshots_updated_at
before update on public.asset_liability_monthly_snapshots
for each row execute function public.set_asset_liability_updated_at();

alter table public.asset_liability_monthly_states enable row level security;
alter table public.asset_liability_income_plans enable row level security;
alter table public.asset_liability_recurring_income_templates enable row level security;
alter table public.asset_liability_payment_source_settings enable row level security;
alter table public.asset_liability_monthly_snapshots enable row level security;

drop policy if exists asset_liability_monthly_states_select_own
  on public.asset_liability_monthly_states;
create policy asset_liability_monthly_states_select_own
on public.asset_liability_monthly_states
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_states_insert_own
  on public.asset_liability_monthly_states;
create policy asset_liability_monthly_states_insert_own
on public.asset_liability_monthly_states
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_states_update_own
  on public.asset_liability_monthly_states;
create policy asset_liability_monthly_states_update_own
on public.asset_liability_monthly_states
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_states_delete_own
  on public.asset_liability_monthly_states;
create policy asset_liability_monthly_states_delete_own
on public.asset_liability_monthly_states
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_income_plans_select_own
  on public.asset_liability_income_plans;
create policy asset_liability_income_plans_select_own
on public.asset_liability_income_plans
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_income_plans_insert_own
  on public.asset_liability_income_plans;
create policy asset_liability_income_plans_insert_own
on public.asset_liability_income_plans
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_liability_income_plans_update_own
  on public.asset_liability_income_plans;
create policy asset_liability_income_plans_update_own
on public.asset_liability_income_plans
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_liability_income_plans_delete_own
  on public.asset_liability_income_plans;
create policy asset_liability_income_plans_delete_own
on public.asset_liability_income_plans
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_recurring_income_templates_select_own
  on public.asset_liability_recurring_income_templates;
create policy asset_liability_recurring_income_templates_select_own
on public.asset_liability_recurring_income_templates
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_recurring_income_templates_insert_own
  on public.asset_liability_recurring_income_templates;
create policy asset_liability_recurring_income_templates_insert_own
on public.asset_liability_recurring_income_templates
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_liability_recurring_income_templates_update_own
  on public.asset_liability_recurring_income_templates;
create policy asset_liability_recurring_income_templates_update_own
on public.asset_liability_recurring_income_templates
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_liability_recurring_income_templates_delete_own
  on public.asset_liability_recurring_income_templates;
create policy asset_liability_recurring_income_templates_delete_own
on public.asset_liability_recurring_income_templates
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_payment_source_settings_select_own
  on public.asset_liability_payment_source_settings;
create policy asset_liability_payment_source_settings_select_own
on public.asset_liability_payment_source_settings
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_payment_source_settings_insert_own
  on public.asset_liability_payment_source_settings;
create policy asset_liability_payment_source_settings_insert_own
on public.asset_liability_payment_source_settings
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_liability_payment_source_settings_update_own
  on public.asset_liability_payment_source_settings;
create policy asset_liability_payment_source_settings_update_own
on public.asset_liability_payment_source_settings
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_liability_payment_source_settings_delete_own
  on public.asset_liability_payment_source_settings;
create policy asset_liability_payment_source_settings_delete_own
on public.asset_liability_payment_source_settings
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_snapshots_select_own
  on public.asset_liability_monthly_snapshots;
create policy asset_liability_monthly_snapshots_select_own
on public.asset_liability_monthly_snapshots
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_snapshots_insert_own
  on public.asset_liability_monthly_snapshots;
create policy asset_liability_monthly_snapshots_insert_own
on public.asset_liability_monthly_snapshots
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_snapshots_update_own
  on public.asset_liability_monthly_snapshots;
create policy asset_liability_monthly_snapshots_update_own
on public.asset_liability_monthly_snapshots
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_liability_monthly_snapshots_delete_own
  on public.asset_liability_monthly_snapshots;
create policy asset_liability_monthly_snapshots_delete_own
on public.asset_liability_monthly_snapshots
for delete
to authenticated
using (auth.uid() = user_id);

comment on table public.asset_liability_monthly_states is
  'Monthly asset/liability payment override and paid-state payloads. SharedPreferences remains primary until the Supabase repository adapter is enabled.';
comment on table public.asset_liability_income_plans is
  'Monthly income plan payloads for the asset/liability board.';
comment on table public.asset_liability_recurring_income_templates is
  'Recurring income template payloads. Use month_key = global for the default template set.';
comment on table public.asset_liability_payment_source_settings is
  'Payment source override and default-account payloads. Use month_key = global for default settings.';
comment on table public.asset_liability_monthly_snapshots is
  'Saved-at-time monthly snapshot payloads for history charts and CSV backup.';

comment on column public.asset_liability_monthly_states.payload is
  'JSON object payload. Collection-like values should be stored under explicit keys such as items or paid_account_ids.';
comment on column public.asset_liability_income_plans.payload is
  'JSON object payload. Expected shape: {items: [...]} for income plans.';
comment on column public.asset_liability_recurring_income_templates.payload is
  'JSON object payload. Expected shape: {items: [...]} for recurring income templates.';
comment on column public.asset_liability_payment_source_settings.payload is
  'JSON object payload. Expected shape: {payment_source_account_ids: {...}, default_payment_source_account_ids: {...}}.';
comment on column public.asset_liability_monthly_snapshots.payload is
  'JSON object payload containing saved_at, asset totals, liability totals, cash-like totals, payment totals, and overdue count.';
