-- Migration for Issue #2586: External regulation and supply-chain impact tracking
-- Default verification status is strictly `pending_fact_check` (`事実確認待ち`).

create table if not exists public.external_regulation_impacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  jurisdiction_code text not null
    check (char_length(trim(jurisdiction_code)) between 2 and 16),
  factor_category text not null
    check (
      factor_category in (
        'regulation',
        'political_claim',
        'economic_embargo',
        'supply_chain_disruption'
      )
    ),
  title text not null
    check (char_length(trim(title)) between 1 and 200),
  summary text not null default '',
  affected_product_area text not null
    check (char_length(trim(affected_product_area)) between 1 and 120),
  impact_level text not null
    check (impact_level in ('low', 'medium', 'high', 'critical')),
  verification_status text not null default 'pending_fact_check'
    check (
      verification_status in (
        'pending_fact_check',
        'verified',
        'disputed',
        'resolved'
      )
    ),
  awaiting_fact_check boolean not null default true,
  source_reference text not null
    check (char_length(trim(source_reference)) > 0),
  effective_date date,
  escalation_issue_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_external_regulation_impacts_user_created
  on public.external_regulation_impacts (user_id, created_at desc);

create index if not exists idx_external_regulation_impacts_impact_status
  on public.external_regulation_impacts (impact_level, verification_status);

alter table public.external_regulation_impacts enable row level security;

drop policy if exists "external_regulation_impacts_select_own"
  on public.external_regulation_impacts;
create policy "external_regulation_impacts_select_own"
  on public.external_regulation_impacts
  for select
  using ((select auth.uid()) = user_id);

drop policy if exists "external_regulation_impacts_insert_own"
  on public.external_regulation_impacts;
create policy "external_regulation_impacts_insert_own"
  on public.external_regulation_impacts
  for insert
  with check (
    (select auth.uid()) = user_id
    and verification_status = 'pending_fact_check'
    and awaiting_fact_check = true
  );

drop policy if exists "external_regulation_impacts_update_own"
  on public.external_regulation_impacts;
create policy "external_regulation_impacts_update_own"
  on public.external_regulation_impacts
  for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "external_regulation_impacts_delete_own"
  on public.external_regulation_impacts;
create policy "external_regulation_impacts_delete_own"
  on public.external_regulation_impacts
  for delete
  using ((select auth.uid()) = user_id);

create or replace function public.guard_external_regulation_fact_check_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $guard$
begin
  if coalesce(
       nullif(auth.role(), ''),
       nullif(current_setting('request.jwt.claim.role', true), ''),
       ''
     ) = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and coalesce(
         nullif(auth.role(), ''),
         nullif(current_setting('request.jwt.claim.role', true), ''),
         ''
       ) = ''
     ) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.verification_status is distinct from 'pending_fact_check'
       or new.awaiting_fact_check is distinct from true then
      raise exception 'Cannot bypass initial pending_fact_check status'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id then
      raise exception 'Cannot reassign external regulation impact ownership'
        using errcode = '42501';
    end if;
    if new.verification_status is distinct from old.verification_status
       or new.awaiting_fact_check is distinct from old.awaiting_fact_check then
      raise exception 'Only service_role may modify fact-check status'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_external_regulation_fact_check_fields
  on public.external_regulation_impacts;
create trigger guard_external_regulation_fact_check_fields
  before insert or update on public.external_regulation_impacts
  for each row
  execute function public.guard_external_regulation_fact_check_fields();

comment on function public.guard_external_regulation_fact_check_fields() is
  'Blocks non-service_role tampering with verification_status and awaiting_fact_check on insert or update.';
