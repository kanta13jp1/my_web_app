-- REVIEW DRAFT ONLY. Not a deployed migration. No bank integration or cron.
-- This initial contract records owner assertions, never bank-verified claims.
begin;

create table public.asset_payroll_accounts (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  display_label text not null check (length(display_label) between 1 and 120),
  target_increase_yen bigint check (target_increase_yen >= 0),
  archived boolean not null default false,
  primary key (user_id, id)
);

create table public.asset_payroll_balance_observations (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  account_id uuid not null,
  payroll_month date not null check (extract(day from payroll_month) = 1),
  deposit_reference text not null check (length(deposit_reference) between 1 and 120),
  deposit_date date not null,
  date_precision text not null check (date_precision in ('day', 'instant')),
  deposited_at timestamptz,
  observed_at timestamptz,
  balance_yen bigint not null,
  evidence_kind text not null default 'owner_confirmed_at_deposit'
    check (evidence_kind = 'owner_confirmed_at_deposit'),
  source_note text not null check (length(source_note) between 1 and 300),
  confirmation_version text not null check (confirmation_version = 'immediate-balance-v1'),
  selection_reason text not null check (length(selection_reason) between 1 and 300),
  expected_previous_id uuid,
  request_id uuid not null,
  recorded_at timestamptz not null default now(),
  primary key (user_id, id),
  unique (user_id, request_id),
  unique (user_id, account_id, payroll_month, id),
  foreign key (user_id, account_id) references public.asset_payroll_accounts(user_id, id),
  foreign key (user_id, account_id, payroll_month, expected_previous_id)
    references public.asset_payroll_balance_observations(user_id, account_id, payroll_month, id),
  check (
    (date_precision = 'day' and deposited_at is null and observed_at is null)
    or (date_precision = 'instant' and deposited_at is not null
      and observed_at is not null and observed_at >= deposited_at
      and deposit_date = (deposited_at at time zone 'Asia/Tokyo')::date)
  )
);

create table public.asset_payroll_balance_selections (
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null,
  payroll_month date not null,
  observation_id uuid not null,
  reason text not null check (length(reason) between 1 and 300),
  primary key (user_id, account_id, payroll_month),
  foreign key (user_id, account_id, payroll_month, observation_id)
    references public.asset_payroll_balance_observations(user_id, account_id, payroll_month, id)
);

create table public.asset_payroll_balance_selection_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null,
  payroll_month date not null,
  old_observation_id uuid,
  new_observation_id uuid not null,
  reason text not null,
  changed_at timestamptz not null default now(),
  foreign key (user_id, account_id, payroll_month, old_observation_id)
    references public.asset_payroll_balance_observations(user_id, account_id, payroll_month, id),
  foreign key (user_id, account_id, payroll_month, new_observation_id)
    references public.asset_payroll_balance_observations(user_id, account_id, payroll_month, id)
);
create index payroll_history_owner_month_idx
  on public.asset_payroll_balance_selection_history(user_id, account_id, payroll_month, id desc);
create index payroll_history_owner_observation_idx
  on public.asset_payroll_balance_selection_history(user_id, new_observation_id);

alter table public.asset_payroll_accounts enable row level security;
alter table public.asset_payroll_balance_observations enable row level security;
alter table public.asset_payroll_balance_selections enable row level security;
alter table public.asset_payroll_balance_selection_history enable row level security;

revoke all on public.asset_payroll_accounts,
  public.asset_payroll_balance_observations,
  public.asset_payroll_balance_selections,
  public.asset_payroll_balance_selection_history from public, anon, authenticated;

grant select on public.asset_payroll_accounts,
  public.asset_payroll_balance_observations,
  public.asset_payroll_balance_selections,
  public.asset_payroll_balance_selection_history to authenticated;
grant insert (user_id, id, display_label, target_increase_yen, archived),
  update (display_label, target_increase_yen, archived)
  on public.asset_payroll_accounts to authenticated;
-- No client DML on observations or selections: every write must enforce the
-- explicit confirmation, idempotent payload and expected-selection contract.

create policy payroll_accounts_owner_select on public.asset_payroll_accounts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy payroll_accounts_owner_insert on public.asset_payroll_accounts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy payroll_accounts_owner_update on public.asset_payroll_accounts
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy payroll_observations_owner_select on public.asset_payroll_balance_observations
  for select to authenticated using ((select auth.uid()) = user_id);
create policy payroll_selections_owner_select on public.asset_payroll_balance_selections
  for select to authenticated using ((select auth.uid()) = user_id);
create policy payroll_history_owner_select on public.asset_payroll_balance_selection_history
  for select to authenticated using ((select auth.uid()) = user_id);

-- Trigger only: privileged append is necessary because clients cannot modify
-- audit history. No network calls and no flow/current-balance writes.
create schema if not exists payroll_snapshot_private;
revoke all on schema payroll_snapshot_private from public, anon, authenticated;
create function payroll_snapshot_private.audit_selection() returns trigger
language plpgsql security definer set search_path = '' as $audit$
begin
  if auth.uid() is null or auth.uid() <> new.user_id then
    raise exception 'Payroll selection owner mismatch' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id or new.account_id <> old.account_id
      or new.payroll_month <> old.payroll_month then
      raise exception 'Payroll selection identity is immutable' using errcode = '23514';
    end if;
    if new.observation_id = old.observation_id and new.reason = old.reason then
      return new;
    end if;
  end if;
  insert into public.asset_payroll_balance_selection_history (
    user_id, account_id, payroll_month, old_observation_id, new_observation_id, reason
  ) values (
    new.user_id, new.account_id, new.payroll_month,
    case when tg_op = 'UPDATE' then old.observation_id else null end,
    new.observation_id, new.reason
  );
  return new;
end;
$audit$;
revoke all on function payroll_snapshot_private.audit_selection()
  from public, anon, authenticated;
create trigger payroll_selection_audit
  after insert or update on public.asset_payroll_balance_selections
  for each row execute function payroll_snapshot_private.audit_selection();

create function payroll_snapshot_private.confirm_payroll_balance_observation(
  p_account_id uuid, p_payroll_month date, p_deposit_reference text,
  p_deposit_date date, p_date_precision text,
  p_deposited_at timestamptz, p_observed_at timestamptz,
  p_balance_yen bigint, p_source_note text, p_request_id uuid,
  p_expected_previous_id uuid, p_reason text, p_confirm_immediate boolean
) returns uuid
language plpgsql security definer set search_path = '' as $confirm$
declare
  v_user uuid := auth.uid();
  v_observation public.asset_payroll_balance_observations%rowtype;
  v_current uuid;
  v_selection_found boolean;
begin
  if v_user is null or p_confirm_immediate is distinct from true then
    raise exception 'Explicit owner confirmation required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.asset_payroll_accounts
    where user_id = v_user and id = p_account_id and not archived) then
    raise exception 'Payroll account unavailable' using errcode = '42501';
  end if;
  insert into public.asset_payroll_balance_observations (
    user_id, account_id, payroll_month, deposit_reference, deposit_date, date_precision, deposited_at,
    observed_at, balance_yen, source_note, request_id, confirmation_version,
    selection_reason, expected_previous_id
  ) values (
    v_user, p_account_id, p_payroll_month, p_deposit_reference, p_deposit_date, p_date_precision, p_deposited_at,
    p_observed_at, p_balance_yen, p_source_note, p_request_id, 'immediate-balance-v1',
    p_reason, p_expected_previous_id
  ) on conflict (user_id, request_id) do nothing;
  select * into strict v_observation from public.asset_payroll_balance_observations
    where user_id = v_user and request_id = p_request_id;
  if v_observation.account_id is distinct from p_account_id
    or v_observation.payroll_month is distinct from p_payroll_month
    or v_observation.deposit_reference is distinct from p_deposit_reference
    or v_observation.deposit_date is distinct from p_deposit_date
    or v_observation.date_precision is distinct from p_date_precision
    or v_observation.deposited_at is distinct from p_deposited_at
    or v_observation.observed_at is distinct from p_observed_at
    or v_observation.balance_yen is distinct from p_balance_yen
    or v_observation.source_note is distinct from p_source_note
    or v_observation.expected_previous_id is distinct from p_expected_previous_id
    or v_observation.selection_reason is distinct from p_reason then
    raise exception 'Request reused with different content' using errcode = '22023';
  end if;
  -- A successful old request can be replayed after a later correction without
  -- moving the selected pointer backwards or adding another history row.
  if exists (select 1 from public.asset_payroll_balance_selection_history
    where user_id = v_user and new_observation_id = v_observation.id) then
    return v_observation.id;
  end if;
  select observation_id into v_current from public.asset_payroll_balance_selections
    where user_id = v_user and account_id = p_account_id
      and payroll_month = p_payroll_month for update;
  v_selection_found := found;
  if v_current is distinct from p_expected_previous_id then
    raise exception 'Payroll observation changed; reload before correcting'
      using errcode = '40001';
  end if;
  if v_selection_found then
    update public.asset_payroll_balance_selections
      set observation_id = v_observation.id, reason = p_reason
      where user_id = v_user and account_id = p_account_id
        and payroll_month = p_payroll_month;
  else
    insert into public.asset_payroll_balance_selections (
      user_id, account_id, payroll_month, observation_id, reason
    ) values (v_user, p_account_id, p_payroll_month, v_observation.id, p_reason)
    on conflict (user_id, account_id, payroll_month) do nothing;
    if not found then
      raise exception 'Payroll observation created concurrently; reload'
        using errcode = '40001';
    end if;
  end if;
  return v_observation.id;
end;
$confirm$;
revoke all on function payroll_snapshot_private.confirm_payroll_balance_observation(
  uuid, date, text, date, text, timestamptz, timestamptz, bigint, text, uuid, uuid, text, boolean
) from public, anon, authenticated;
grant usage on schema payroll_snapshot_private to authenticated;
grant execute on function payroll_snapshot_private.confirm_payroll_balance_observation(
  uuid, date, text, date, text, timestamptz, timestamptz, bigint, text, uuid, uuid, text, boolean
) to authenticated;

-- Only the narrow wrapper is exposed through the public Data API. The private
-- implementation performs auth.uid ownership checks for every touched row.
create function public.confirm_payroll_balance_observation(
  p_account_id uuid, p_payroll_month date, p_deposit_reference text,
  p_deposit_date date, p_date_precision text,
  p_deposited_at timestamptz, p_observed_at timestamptz,
  p_balance_yen bigint, p_source_note text, p_request_id uuid,
  p_expected_previous_id uuid, p_reason text, p_confirm_immediate boolean
) returns uuid
language sql security invoker set search_path = '' as $wrapper$
  select payroll_snapshot_private.confirm_payroll_balance_observation(
    p_account_id, p_payroll_month, p_deposit_reference,
    p_deposit_date, p_date_precision, p_deposited_at, p_observed_at,
    p_balance_yen, p_source_note, p_request_id, p_expected_previous_id,
    p_reason, p_confirm_immediate
  );
$wrapper$;
revoke all on function public.confirm_payroll_balance_observation(
  uuid, date, text, date, text, timestamptz, timestamptz, bigint, text, uuid, uuid, text, boolean
) from public, anon, authenticated;
grant execute on function public.confirm_payroll_balance_observation(
  uuid, date, text, date, text, timestamptz, timestamptz, bigint, text, uuid, uuid, text, boolean
) to authenticated;
commit;
