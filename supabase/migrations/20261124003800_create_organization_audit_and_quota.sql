-- Organization audit logging and resource quota management (#2692).
-- Complements existing team workspaces (teams, team_memberships, team_shared_notes)
-- with append-only audit trails, automatic triggers for permission and resource
-- changes, atomic per-organization quota enforcement (HTTP 429 block payload),
-- and 80% warning admin alert triggers.

create table if not exists public.organization_audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.teams (id) on delete cascade,
  actor_user_id uuid references auth.users (id) on delete set null,
  actor_role text not null default 'authenticated' check (
    char_length(trim(actor_role)) between 1 and 60
  ),
  event_type text not null check (
    event_type in (
      'login',
      'permission_change',
      'resource_create',
      'resource_delete',
      'quota_warning_80',
      'quota_limit_exceeded',
      'quota_policy_update'
    )
  ),
  resource_type text not null check (
    char_length(trim(resource_type)) between 1 and 80
  ),
  resource_id text not null default '' check (
    char_length(resource_id) <= 160
  ),
  summary text not null default '' check (
    char_length(summary) <= 500
  ),
  metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(metadata) = 'object'
  ),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_organization_audit_logs_org_created
  on public.organization_audit_logs (organization_id, created_at desc);

create index if not exists idx_organization_audit_logs_actor_created
  on public.organization_audit_logs (actor_user_id, created_at desc);

create index if not exists idx_organization_audit_logs_event_created
  on public.organization_audit_logs (event_type, created_at desc);

alter table public.organization_audit_logs enable row level security;

revoke all on table public.organization_audit_logs from public, anon, authenticated;
grant select on table public.organization_audit_logs to authenticated;
grant all on table public.organization_audit_logs to service_role;

drop policy if exists "organization_audit_logs_select_authorized"
  on public.organization_audit_logs;
create policy "organization_audit_logs_select_authorized"
  on public.organization_audit_logs
  for select
  to authenticated
  using (
    actor_user_id = (select auth.uid())
    or exists (
      select 1
      from public.teams t
      where t.id = organization_audit_logs.organization_id
        and t.owner_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.team_memberships tm
      where tm.team_id = organization_audit_logs.organization_id
        and tm.user_id = (select auth.uid())
        and tm.role = 'admin'
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  );

drop policy if exists "organization_audit_logs_deny_client_insert"
  on public.organization_audit_logs;
create policy "organization_audit_logs_deny_client_insert"
  on public.organization_audit_logs
  for insert
  to anon, authenticated
  with check (false);

drop policy if exists "organization_audit_logs_deny_client_update"
  on public.organization_audit_logs;
create policy "organization_audit_logs_deny_client_update"
  on public.organization_audit_logs
  for update
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists "organization_audit_logs_deny_client_delete"
  on public.organization_audit_logs;
create policy "organization_audit_logs_deny_client_delete"
  on public.organization_audit_logs
  for delete
  to anon, authenticated
  using (false);

drop policy if exists "organization_audit_logs_service_role_all"
  on public.organization_audit_logs;
create policy "organization_audit_logs_service_role_all"
  on public.organization_audit_logs
  for all
  to service_role
  using (true)
  with check (true);

create table if not exists public.organization_quotas (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.teams (id) on delete cascade,
  resource_type text not null check (
    resource_type in ('api_calls', 'compute_units', 'storage_mb')
  ),
  period_key text not null check (
    period_key ~ '^\d{4}-(0[1-9]|1[0-2])$'
  ),
  limit_amount integer not null check (limit_amount > 0),
  used_amount integer not null default 0 check (used_amount >= 0),
  warning_threshold_pct numeric(5, 2) not null default 80.00 check (
    warning_threshold_pct >= 1 and warning_threshold_pct <= 100
  ),
  warning_80_triggered_at timestamptz,
  last_exceeded_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, resource_type, period_key)
);

create index if not exists idx_organization_quotas_org_period
  on public.organization_quotas (organization_id, period_key, resource_type);

alter table public.organization_quotas enable row level security;

revoke all on table public.organization_quotas from public, anon, authenticated;
grant select on table public.organization_quotas to authenticated;
grant all on table public.organization_quotas to service_role;

drop policy if exists "organization_quotas_select_member_or_admin"
  on public.organization_quotas;
create policy "organization_quotas_select_member_or_admin"
  on public.organization_quotas
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.teams t
      where t.id = organization_quotas.organization_id
        and t.owner_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.team_memberships tm
      where tm.team_id = organization_quotas.organization_id
        and tm.user_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  );

drop policy if exists "organization_quotas_deny_client_write"
  on public.organization_quotas;
create policy "organization_quotas_deny_client_write"
  on public.organization_quotas
  for insert
  to anon, authenticated
  with check (false);

drop policy if exists "organization_quotas_deny_client_update"
  on public.organization_quotas;
create policy "organization_quotas_deny_client_update"
  on public.organization_quotas
  for update
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists "organization_quotas_deny_client_delete"
  on public.organization_quotas;
create policy "organization_quotas_deny_client_delete"
  on public.organization_quotas
  for delete
  to anon, authenticated
  using (false);

drop policy if exists "organization_quotas_service_role_all"
  on public.organization_quotas;
create policy "organization_quotas_service_role_all"
  on public.organization_quotas
  for all
  to service_role
  using (true)
  with check (true);

create table if not exists public.organization_quota_alerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.teams (id) on delete cascade,
  resource_type text not null check (
    resource_type in ('api_calls', 'compute_units', 'storage_mb')
  ),
  period_key text not null check (
    period_key ~ '^\d{4}-(0[1-9]|1[0-2])$'
  ),
  alert_level text not null check (
    alert_level in ('warning_80', 'limit_100')
  ),
  usage_pct numeric(6, 2) not null check (usage_pct >= 0),
  used_amount integer not null check (used_amount >= 0),
  limit_amount integer not null check (limit_amount > 0),
  message text not null check (
    char_length(trim(message)) between 1 and 500
  ),
  admin_notified boolean not null default false,
  notified_at timestamptz,
  acknowledged_by uuid references auth.users (id) on delete set null,
  acknowledged_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, resource_type, period_key, alert_level)
);

create index if not exists idx_organization_quota_alerts_org_created
  on public.organization_quota_alerts (organization_id, created_at desc);

alter table public.organization_quota_alerts enable row level security;

revoke all on table public.organization_quota_alerts from public, anon, authenticated;
grant select on table public.organization_quota_alerts to authenticated;
grant all on table public.organization_quota_alerts to service_role;

drop policy if exists "organization_quota_alerts_select_admin"
  on public.organization_quota_alerts;
create policy "organization_quota_alerts_select_admin"
  on public.organization_quota_alerts
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.teams t
      where t.id = organization_quota_alerts.organization_id
        and t.owner_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.team_memberships tm
      where tm.team_id = organization_quota_alerts.organization_id
        and tm.user_id = (select auth.uid())
        and tm.role = 'admin'
    )
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  );

drop policy if exists "organization_quota_alerts_deny_client_insert"
  on public.organization_quota_alerts;
create policy "organization_quota_alerts_deny_client_insert"
  on public.organization_quota_alerts
  for insert
  to anon, authenticated
  with check (false);

drop policy if exists "organization_quota_alerts_deny_client_update"
  on public.organization_quota_alerts;
create policy "organization_quota_alerts_deny_client_update"
  on public.organization_quota_alerts
  for update
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists "organization_quota_alerts_deny_client_delete"
  on public.organization_quota_alerts;
create policy "organization_quota_alerts_deny_client_delete"
  on public.organization_quota_alerts
  for delete
  to anon, authenticated
  using (false);

drop policy if exists "organization_quota_alerts_service_role_all"
  on public.organization_quota_alerts;
create policy "organization_quota_alerts_service_role_all"
  on public.organization_quota_alerts
  for all
  to service_role
  using (true)
  with check (true);

create or replace function public._org_audit_is_service_role()
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_raw_claims text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb;
  v_jwt_role text;
begin
  if v_raw_claims is not null then
    begin
      v_claims := v_raw_claims::jsonb;
    exception
      when others then
        v_claims := null;
    end;
  end if;

  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  return (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
end;
$fn$;

revoke all on function public._org_audit_is_service_role() from public, anon, authenticated;

create or replace function public._org_audit_has_org_access(
  p_organization_id uuid,
  p_user_id uuid,
  p_require_admin boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
  select
    p_user_id is not null
    and (
      exists (
        select 1
        from public.user_profiles up
        where up.user_id = p_user_id
          and (up.is_admin = true or up.role = 'admin')
      )
      or (
        p_organization_id is not null
        and (
          exists (
            select 1
            from public.teams t
            where t.id = p_organization_id
              and t.owner_id = p_user_id
          )
          or exists (
            select 1
            from public.team_memberships tm
            where tm.team_id = p_organization_id
              and tm.user_id = p_user_id
              and (not p_require_admin or tm.role = 'admin')
          )
        )
      )
    );
$fn$;

revoke all on function public._org_audit_has_org_access(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function public._org_audit_resolve_existing_actor(
  p_uid uuid,
  p_fallback uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_candidate uuid := coalesce(p_uid, p_fallback);
begin
  if v_candidate is not null and exists (
    select 1 from auth.users u where u.id = v_candidate
  ) then
    return v_candidate;
  end if;
  return null;
end;
$fn$;

revoke all on function public._org_audit_resolve_existing_actor(uuid, uuid) from public, anon, authenticated;

create or replace function public.prevent_organization_audit_log_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $fn$
begin
  raise exception 'organization_audit_logs is append-only; UPDATE and DELETE are prohibited'
    using errcode = '42501';
end;
$fn$;

revoke all on function public.prevent_organization_audit_log_mutation() from public, anon, authenticated;

drop trigger if exists trg_prevent_organization_audit_log_mutation
  on public.organization_audit_logs;
create trigger trg_prevent_organization_audit_log_mutation
  before update or delete on public.organization_audit_logs
  for each row
  execute function public.prevent_organization_audit_log_mutation();

create or replace function public.log_team_membership_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_target_user uuid;
  v_event_type text;
  v_summary text;
  v_metadata jsonb;
begin
  if tg_op = 'INSERT' then
    v_org_id := new.team_id;
    v_target_user := new.user_id;
    v_event_type := 'permission_change';
    v_summary := format('組織メンバー追加 (role=%s)', new.role);
    v_metadata := jsonb_build_object(
      'target_user_id', new.user_id,
      'new_role', new.role,
      'operation', 'INSERT'
    );
  elsif tg_op = 'UPDATE' then
    if new.role is not distinct from old.role then
      return new;
    end if;
    v_org_id := new.team_id;
    v_target_user := new.user_id;
    v_event_type := 'permission_change';
    v_summary := format('組織メンバー権限変更 (%s -> %s)', old.role, new.role);
    v_metadata := jsonb_build_object(
      'target_user_id', new.user_id,
      'previous_role', old.role,
      'new_role', new.role,
      'operation', 'UPDATE'
    );
  else
    v_target_user := old.user_id;
    if exists (select 1 from public.teams t where t.id = old.team_id) then
      v_org_id := old.team_id;
    else
      v_org_id := null;
    end if;
    v_event_type := 'resource_delete';
    v_summary := format('組織メンバー削除 (role=%s)', old.role);
    v_metadata := jsonb_build_object(
      'target_user_id', old.user_id,
      'previous_role', old.role,
      'deleted_team_id', old.team_id,
      'operation', 'DELETE'
    );
  end if;

  insert into public.organization_audit_logs (
    organization_id,
    actor_user_id,
    actor_role,
    event_type,
    resource_type,
    resource_id,
    summary,
    metadata
  ) values (
    v_org_id,
    public._org_audit_resolve_existing_actor(v_uid, v_target_user),
    case when public._org_audit_is_service_role() then 'service_role' else 'authenticated' end,
    v_event_type,
    'team_membership',
    coalesce(v_target_user::text, ''),
    v_summary,
    v_metadata
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

revoke all on function public.log_team_membership_audit_trigger() from public, anon, authenticated;

drop trigger if exists trg_log_team_membership_audit
  on public.team_memberships;
create trigger trg_log_team_membership_audit
  after insert or update or delete on public.team_memberships
  for each row
  execute function public.log_team_membership_audit_trigger();

create or replace function public.log_team_shared_note_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_shared_by uuid;
  v_note_id bigint;
  v_event_type text;
  v_summary text;
  v_metadata jsonb;
begin
  if tg_op = 'INSERT' then
    v_org_id := new.team_id;
    v_shared_by := new.shared_by;
    v_note_id := new.note_id;
    v_event_type := 'resource_create';
    v_summary := format('組織共有ノート作成 (note_id=%s)', new.note_id);
    v_metadata := jsonb_build_object(
      'note_id', new.note_id,
      'team_id', new.team_id,
      'operation', 'INSERT'
    );
  else
    v_shared_by := old.shared_by;
    v_note_id := old.note_id;
    if exists (select 1 from public.teams t where t.id = old.team_id) then
      v_org_id := old.team_id;
    else
      v_org_id := null;
    end if;
    v_event_type := 'resource_delete';
    v_summary := format('組織共有ノート削除 (note_id=%s)', old.note_id);
    v_metadata := jsonb_build_object(
      'note_id', old.note_id,
      'deleted_team_id', old.team_id,
      'operation', 'DELETE'
    );
  end if;

  insert into public.organization_audit_logs (
    organization_id,
    actor_user_id,
    actor_role,
    event_type,
    resource_type,
    resource_id,
    summary,
    metadata
  ) values (
    v_org_id,
    public._org_audit_resolve_existing_actor(v_uid, v_shared_by),
    case when public._org_audit_is_service_role() then 'service_role' else 'authenticated' end,
    v_event_type,
    'team_shared_note',
    coalesce(v_note_id::text, ''),
    v_summary,
    v_metadata
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

revoke all on function public.log_team_shared_note_audit_trigger() from public, anon, authenticated;

drop trigger if exists trg_log_team_shared_note_audit
  on public.team_shared_notes;
create trigger trg_log_team_shared_note_audit
  after insert or delete on public.team_shared_notes
  for each row
  execute function public.log_team_shared_note_audit_trigger();

create or replace function public.log_user_profile_privilege_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  insert into public.organization_audit_logs (
    organization_id,
    actor_user_id,
    actor_role,
    event_type,
    resource_type,
    resource_id,
    summary,
    metadata
  ) values (
    null,
    public._org_audit_resolve_existing_actor(v_uid, new.user_id),
    case when public._org_audit_is_service_role() then 'service_role' else 'authenticated' end,
    'permission_change',
    'user_profile_privilege',
    new.user_id::text,
    'ユーザー権限変更 (user_profiles)',
    jsonb_build_object(
      'target_user_id', new.user_id,
      'previous_is_admin', old.is_admin,
      'new_is_admin', new.is_admin,
      'previous_role', old.role,
      'new_role', new.role
    )
  );
  return new;
end;
$fn$;

revoke all on function public.log_user_profile_privilege_audit_trigger() from public, anon, authenticated;

drop trigger if exists trg_log_user_profile_privilege_audit
  on public.user_profiles;
create trigger trg_log_user_profile_privilege_audit
  after update on public.user_profiles
  for each row
  when (new.is_admin is distinct from old.is_admin or new.role is distinct from old.role)
  execute function public.log_user_profile_privilege_audit_trigger();

create or replace function public.record_organization_audit_event(
  p_organization_id uuid default null,
  p_actor_user_id uuid default null,
  p_actor_role text default 'authenticated',
  p_event_type text default 'login',
  p_resource_type text default 'session',
  p_resource_id text default '',
  p_summary text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns public.organization_audit_logs
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_is_service boolean := public._org_audit_is_service_role();
  v_uid uuid := auth.uid();
  v_effective_actor uuid;
  v_inserted public.organization_audit_logs;
begin
  if not v_is_service then
    if v_uid is null then
      raise exception 'Authentication required to record audit event'
        using errcode = '42501';
    end if;
    if p_actor_user_id is not null and p_actor_user_id is distinct from v_uid then
      raise exception 'Cannot forge audit actor_user_id'
        using errcode = '42501';
    end if;
    if p_organization_id is not null
       and not public._org_audit_has_org_access(p_organization_id, v_uid, false) then
      raise exception 'Not authorized for organization audit recording'
        using errcode = '42501';
    end if;
    v_effective_actor := v_uid;
  else
    v_effective_actor := coalesce(p_actor_user_id, v_uid);
  end if;

  if coalesce(trim(p_event_type), '') = '' then
    raise exception 'event_type is required'
      using errcode = '22023';
  end if;
  if coalesce(trim(p_resource_type), '') = '' then
    raise exception 'resource_type is required'
      using errcode = '22023';
  end if;

  insert into public.organization_audit_logs (
    organization_id,
    actor_user_id,
    actor_role,
    event_type,
    resource_type,
    resource_id,
    summary,
    metadata
  ) values (
    p_organization_id,
    v_effective_actor,
    coalesce(nullif(trim(p_actor_role), ''), case when v_is_service then 'service_role' else 'authenticated' end),
    trim(p_event_type),
    trim(p_resource_type),
    left(coalesce(p_resource_id, ''), 160),
    left(coalesce(p_summary, ''), 500),
    case when jsonb_typeof(p_metadata) = 'object' then p_metadata else '{}'::jsonb end
  )
  returning * into v_inserted;

  return v_inserted;
end;
$fn$;

revoke all on function public.record_organization_audit_event(uuid, uuid, text, text, text, text, text, jsonb) from public, anon;
grant execute on function public.record_organization_audit_event(uuid, uuid, text, text, text, text, text, jsonb) to authenticated, service_role;

create or replace function public.consume_organization_quota(
  p_organization_id uuid,
  p_resource_type text default 'api_calls',
  p_units integer default 1,
  p_actor_user_id uuid default null,
  p_period_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_is_service boolean := public._org_audit_is_service_role();
  v_uid uuid := auth.uid();
  v_effective_actor uuid;
  v_period text := coalesce(nullif(trim(p_period_key), ''), to_char(timezone('Asia/Tokyo', now()), 'YYYY-MM'));
  v_resource text := lower(trim(coalesce(p_resource_type, 'api_calls')));
  v_default_limit integer;
  v_row public.organization_quotas;
  v_next_used integer;
  v_usage_pct numeric(6, 2);
  v_warn_newly_triggered boolean := false;
begin
  if p_organization_id is null then
    raise exception 'p_organization_id is required'
      using errcode = '22023';
  end if;
  if p_units is null or p_units < 1 or p_units > 100000 then
    raise exception 'p_units must be between 1 and 100000'
      using errcode = '22023';
  end if;
  if v_resource not in ('api_calls', 'compute_units', 'storage_mb') then
    raise exception 'Unsupported resource_type: %', v_resource
      using errcode = '22023';
  end if;

  if not v_is_service then
    if v_uid is null then
      raise exception 'Authentication required'
        using errcode = '42501';
    end if;
    if not public._org_audit_has_org_access(p_organization_id, v_uid, false) then
      raise exception 'Organization membership required'
        using errcode = '42501';
    end if;
    v_effective_actor := v_uid;
  else
    v_effective_actor := coalesce(p_actor_user_id, v_uid);
  end if;

  v_default_limit := case v_resource
    when 'api_calls' then 1000
    when 'compute_units' then 500
    else 2048
  end;

  insert into public.organization_quotas (
    organization_id,
    resource_type,
    period_key,
    limit_amount,
    used_amount,
    warning_threshold_pct
  ) values (
    p_organization_id,
    v_resource,
    v_period,
    v_default_limit,
    0,
    80.00
  )
  on conflict (organization_id, resource_type, period_key) do nothing;

  select *
  into v_row
  from public.organization_quotas
  where organization_id = p_organization_id
    and resource_type = v_resource
    and period_key = v_period
  for update;

  if v_row.used_amount + p_units > v_row.limit_amount then
    v_usage_pct := round((v_row.used_amount::numeric * 100.0) / v_row.limit_amount::numeric, 2);
    update public.organization_quotas
      set last_exceeded_at = timezone('utc', now()),
          updated_at = timezone('utc', now())
      where id = v_row.id;

    insert into public.organization_quota_alerts (
      organization_id,
      resource_type,
      period_key,
      alert_level,
      usage_pct,
      used_amount,
      limit_amount,
      message,
      admin_notified,
      notified_at
    ) values (
      p_organization_id,
      v_resource,
      v_period,
      'limit_100',
      v_usage_pct,
      v_row.used_amount,
      v_row.limit_amount,
      format('組織の %s 利用量が上限 (%s) に到達しリクエストをブロックしました。', v_resource, v_row.limit_amount),
      true,
      timezone('utc', now())
    )
    on conflict (organization_id, resource_type, period_key, alert_level) do update
      set usage_pct = excluded.usage_pct,
          used_amount = excluded.used_amount,
          limit_amount = excluded.limit_amount;

    insert into public.organization_audit_logs (
      organization_id,
      actor_user_id,
      actor_role,
      event_type,
      resource_type,
      resource_id,
      summary,
      metadata
    ) values (
      p_organization_id,
      v_effective_actor,
      case when v_is_service then 'service_role' else 'authenticated' end,
      'quota_limit_exceeded',
      v_resource,
      v_period,
      format('組織クォータ上限超過でブロック (%s: %s+%s > %s)', v_resource, v_row.used_amount, p_units, v_row.limit_amount),
      jsonb_build_object(
        'period_key', v_period,
        'requested_units', p_units,
        'used_amount', v_row.used_amount,
        'limit_amount', v_row.limit_amount,
        'http_status', 429
      )
    );

    return jsonb_build_object(
      'allowed', false,
      'http_status', 429,
      'code', 'QUOTA_EXCEEDED',
      'error_message', '組織のリソース利用上限に達したため処理をブロックしました。管理者にクォータ引き上げを依頼してください。',
      'organization_id', p_organization_id,
      'resource_type', v_resource,
      'period_key', v_period,
      'used_amount', v_row.used_amount,
      'limit_amount', v_row.limit_amount,
      'remaining', greatest(v_row.limit_amount - v_row.used_amount, 0),
      'usage_pct', v_usage_pct,
      'warning_threshold_pct', v_row.warning_threshold_pct,
      'warning_80_triggered', true,
      'warning_80_newly_triggered', false
    );
  end if;

  v_next_used := v_row.used_amount + p_units;
  v_usage_pct := round((v_next_used::numeric * 100.0) / v_row.limit_amount::numeric, 2);

  if v_usage_pct >= v_row.warning_threshold_pct and v_row.warning_80_triggered_at is null then
    v_warn_newly_triggered := true;
  end if;

  update public.organization_quotas
    set used_amount = v_next_used,
        warning_80_triggered_at = case
          when v_usage_pct >= v_row.warning_threshold_pct then coalesce(v_row.warning_80_triggered_at, timezone('utc', now()))
          else v_row.warning_80_triggered_at
        end,
        updated_at = timezone('utc', now())
    where id = v_row.id;

  if v_usage_pct >= v_row.warning_threshold_pct then
    insert into public.organization_quota_alerts (
      organization_id,
      resource_type,
      period_key,
      alert_level,
      usage_pct,
      used_amount,
      limit_amount,
      message,
      admin_notified,
      notified_at
    ) values (
      p_organization_id,
      v_resource,
      v_period,
      'warning_80',
      v_usage_pct,
      v_next_used,
      v_row.limit_amount,
      format('組織の %s 利用率が警告閾値 (80%%) に到達しました (%s/%s = %s%%)。', v_resource, v_next_used, v_row.limit_amount, v_usage_pct),
      true,
      timezone('utc', now())
    )
    on conflict (organization_id, resource_type, period_key, alert_level) do update
      set usage_pct = excluded.usage_pct,
          used_amount = excluded.used_amount,
          limit_amount = excluded.limit_amount,
          message = excluded.message,
          admin_notified = true,
          notified_at = case
            when v_warn_newly_triggered then excluded.notified_at
            else public.organization_quota_alerts.notified_at
          end,
          acknowledged_by = case
            when v_warn_newly_triggered then null
            else public.organization_quota_alerts.acknowledged_by
          end,
          acknowledged_at = case
            when v_warn_newly_triggered then null
            else public.organization_quota_alerts.acknowledged_at
          end;

    if v_warn_newly_triggered then
      insert into public.organization_audit_logs (
        organization_id,
        actor_user_id,
        actor_role,
        event_type,
        resource_type,
        resource_id,
        summary,
        metadata
      ) values (
        p_organization_id,
        v_effective_actor,
        case when v_is_service then 'service_role' else 'authenticated' end,
        'quota_warning_80',
        v_resource,
        v_period,
        format('組織クォータ80%%警告アラート発火 (%s: %s/%s = %s%%)', v_resource, v_next_used, v_row.limit_amount, v_usage_pct),
        jsonb_build_object(
          'period_key', v_period,
          'used_amount', v_next_used,
          'limit_amount', v_row.limit_amount,
          'usage_pct', v_usage_pct
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'allowed', true,
    'http_status', 200,
    'code', null,
    'error_message', null,
    'organization_id', p_organization_id,
    'resource_type', v_resource,
    'period_key', v_period,
    'used_amount', v_next_used,
    'limit_amount', v_row.limit_amount,
    'remaining', greatest(v_row.limit_amount - v_next_used, 0),
    'usage_pct', v_usage_pct,
    'warning_threshold_pct', v_row.warning_threshold_pct,
    'warning_80_triggered', v_usage_pct >= v_row.warning_threshold_pct,
    'warning_80_newly_triggered', v_warn_newly_triggered
  );
end;
$fn$;

revoke all on function public.consume_organization_quota(uuid, text, integer, uuid, text) from public, anon;
grant execute on function public.consume_organization_quota(uuid, text, integer, uuid, text) to authenticated, service_role;

create or replace function public.update_organization_quota_limit(
  p_organization_id uuid,
  p_resource_type text,
  p_limit_amount integer,
  p_warning_threshold_pct numeric default 80.00,
  p_period_key text default null,
  p_actor_user_id uuid default null
)
returns public.organization_quotas
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_is_service boolean := public._org_audit_is_service_role();
  v_uid uuid := auth.uid();
  v_effective_actor uuid;
  v_period text := coalesce(nullif(trim(p_period_key), ''), to_char(timezone('Asia/Tokyo', now()), 'YYYY-MM'));
  v_resource text := lower(trim(coalesce(p_resource_type, '')));
  v_updated public.organization_quotas;
begin
  if p_organization_id is null then
    raise exception 'p_organization_id is required'
      using errcode = '22023';
  end if;
  if p_limit_amount is null or p_limit_amount <= 0 then
    raise exception 'p_limit_amount must be positive'
      using errcode = '22023';
  end if;
  if p_warning_threshold_pct is null or p_warning_threshold_pct < 1 or p_warning_threshold_pct > 100 then
    raise exception 'p_warning_threshold_pct must be between 1 and 100'
      using errcode = '22023';
  end if;
  if v_resource not in ('api_calls', 'compute_units', 'storage_mb') then
    raise exception 'Unsupported resource_type'
      using errcode = '22023';
  end if;

  if not v_is_service then
    if v_uid is null or not public._org_audit_has_org_access(p_organization_id, v_uid, true) then
      raise exception 'Organization admin or owner permission required'
        using errcode = '42501';
    end if;
    v_effective_actor := v_uid;
  else
    v_effective_actor := coalesce(p_actor_user_id, v_uid);
  end if;

  insert into public.organization_quotas (
    organization_id,
    resource_type,
    period_key,
    limit_amount,
    used_amount,
    warning_threshold_pct,
    updated_at
  ) values (
    p_organization_id,
    v_resource,
    v_period,
    p_limit_amount,
    0,
    p_warning_threshold_pct,
    timezone('utc', now())
  )
  on conflict (organization_id, resource_type, period_key) do update
    set limit_amount = excluded.limit_amount,
        warning_threshold_pct = excluded.warning_threshold_pct,
        warning_80_triggered_at = case
          when (organization_quotas.used_amount::numeric * 100.0) / excluded.limit_amount::numeric < excluded.warning_threshold_pct
          then null
          else organization_quotas.warning_80_triggered_at
        end,
        updated_at = timezone('utc', now())
  returning * into v_updated;

  insert into public.organization_audit_logs (
    organization_id,
    actor_user_id,
    actor_role,
    event_type,
    resource_type,
    resource_id,
    summary,
    metadata
  ) values (
    p_organization_id,
    v_effective_actor,
    case when v_is_service then 'service_role' else 'authenticated' end,
    'quota_policy_update',
    v_resource,
    v_period,
    format('組織クォータ上限設定更新 (%s limit=%s, warn=%s%%)', v_resource, p_limit_amount, p_warning_threshold_pct),
    jsonb_build_object(
      'period_key', v_period,
      'limit_amount', p_limit_amount,
      'warning_threshold_pct', p_warning_threshold_pct
    )
  );

  return v_updated;
end;
$fn$;

revoke all on function public.update_organization_quota_limit(uuid, text, integer, numeric, text, uuid) from public, anon;
grant execute on function public.update_organization_quota_limit(uuid, text, integer, numeric, text, uuid) to authenticated, service_role;

comment on table public.organization_audit_logs is
  'Append-only organization audit log covering login, permission changes, resource lifecycle, and quota enforcement events (#2692).';
comment on table public.organization_quotas is
  'Per-organization resource utilization limits, usage counters, and 80% warning state (#2692).';
comment on table public.organization_quota_alerts is
  'Admin alert notifications emitted at 80% warning threshold and 100% quota block events (#2692).';
