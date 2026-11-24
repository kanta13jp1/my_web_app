-- Migration for Issue #2662: D-ID MCP Proxy Audit Events & Rate-Limit / Upstream Alerting

create table if not exists public.did_mcp_proxy_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  tool_name text not null check (
    tool_name in (
      'did_generate_talk_video',
      'did_agent_chat',
      'did_rag_query',
      'did_mcp_docs_lookup',
      'initialize',
      'tools_list'
    )
  ),
  rpc_method text not null check (rpc_method in ('initialize', 'tools/list', 'tools/call')),
  prompt_summary text not null default '' check (char_length(prompt_summary) <= 500),
  sanitized_params jsonb not null default '{}'::jsonb,
  status text not null check (status in ('queued', 'succeeded', 'rate_limited', 'failed')),
  http_status integer not null default 200 check (http_status between 100 and 599),
  dry_run boolean not null default false,
  alert_dispatched boolean not null default false,
  upstream_host text check (
    upstream_host is null or upstream_host in ('docs.d-id.com', 'api.d-id.com', 'dry-run')
  ),
  error_message text check (error_message is null or char_length(error_message) <= 1000),
  latency_ms integer not null default 0 check (latency_ms >= 0 and latency_ms <= 120000),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_did_mcp_proxy_events_created
  on public.did_mcp_proxy_events (created_at desc);

create index if not exists idx_did_mcp_proxy_events_status_created
  on public.did_mcp_proxy_events (status, created_at desc);

create table if not exists public.did_mcp_alerts (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.did_mcp_proxy_events (id) on delete set null,
  severity text not null check (severity in ('warning', 'critical')),
  alert_type text not null check (
    alert_type in ('rate_limit', 'upstream_error', 'auth_failure', 'timeout')
  ),
  message text not null check (char_length(trim(message)) between 1 and 1000),
  acknowledged boolean not null default false,
  acknowledged_by uuid references auth.users (id) on delete set null,
  acknowledged_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  check (acknowledged = false or acknowledged_at is not null)
);

create index if not exists idx_did_mcp_alerts_ack_created
  on public.did_mcp_alerts (acknowledged, created_at desc);

alter table public.did_mcp_proxy_events enable row level security;
alter table public.did_mcp_alerts enable row level security;

revoke all on table public.did_mcp_proxy_events from public, anon, authenticated;
grant select on table public.did_mcp_proxy_events to authenticated;
grant all on table public.did_mcp_proxy_events to service_role;

revoke all on table public.did_mcp_alerts from public, anon, authenticated;
grant select on table public.did_mcp_alerts to authenticated;
grant all on table public.did_mcp_alerts to service_role;

drop policy if exists "did_mcp_proxy_events_select_owner_or_admin"
  on public.did_mcp_proxy_events;
create policy "did_mcp_proxy_events_select_owner_or_admin"
  on public.did_mcp_proxy_events
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "did_mcp_alerts_select_admin"
  on public.did_mcp_alerts;
create policy "did_mcp_alerts_select_admin"
  on public.did_mcp_alerts
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_did_mcp_proxy_events()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_raw_claims text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb;
  v_jwt_role text;
  v_is_service boolean;
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
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  if not v_is_service then
    raise exception 'did_mcp_proxy_events can only be mutated by service_role'
      using errcode = '42501';
  end if;

  if TG_OP = 'DELETE' then
    return old;
  end if;

  if TG_OP = 'INSERT' then
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    return new;
  end if;

  if new.id is distinct from old.id
    or new.created_at is distinct from old.created_at then
    raise exception 'id and created_at are immutable on did_mcp_proxy_events'
      using errcode = '42501';
  end if;

  return new;
end;
$guard$;

revoke all on function public.guard_did_mcp_proxy_events() from public, anon, authenticated;

drop trigger if exists guard_did_mcp_proxy_events
  on public.did_mcp_proxy_events;
create trigger guard_did_mcp_proxy_events
  before insert or update or delete on public.did_mcp_proxy_events
  for each row
  execute function public.guard_did_mcp_proxy_events();

create or replace function public.guard_did_mcp_alerts()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_raw_claims text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb;
  v_jwt_role text;
  v_is_service boolean;
  v_ack_rpc_active boolean :=
    coalesce(current_setting('app.did_mcp_alert_ack_rpc', true), '') = 'on';
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
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  if TG_OP = 'DELETE' or TG_OP = 'INSERT' then
    if not v_is_service then
      raise exception 'did_mcp_alerts inserts and deletes require service_role'
        using errcode = '42501';
    end if;
    if TG_OP = 'DELETE' then
      return old;
    end if;
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    return new;
  end if;

  if new.id is distinct from old.id
    or new.event_id is distinct from old.event_id
    or new.severity is distinct from old.severity
    or new.alert_type is distinct from old.alert_type
    or new.message is distinct from old.message
    or new.created_at is distinct from old.created_at then
    raise exception 'alert core fields are immutable'
      using errcode = '42501';
  end if;

  if not v_is_service and not v_ack_rpc_active then
    raise exception 'did_mcp_alerts updates must go through acknowledge_did_mcp_alert'
      using errcode = '42501';
  end if;

  if new.acknowledged = true and new.acknowledged_at is null then
    new.acknowledged_at := timezone('utc', now());
  end if;

  return new;
end;
$guard$;

revoke all on function public.guard_did_mcp_alerts() from public, anon, authenticated;

drop trigger if exists guard_did_mcp_alerts
  on public.did_mcp_alerts;
create trigger guard_did_mcp_alerts
  before insert or update or delete on public.did_mcp_alerts
  for each row
  execute function public.guard_did_mcp_alerts();

create or replace function public.acknowledge_did_mcp_alert(p_alert_id uuid)
returns public.did_mcp_alerts
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_updated public.did_mcp_alerts;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.user_profiles up
    where up.user_id = v_uid
      and up.is_admin = true
  )
  into v_is_admin;

  if not v_is_admin then
    raise exception 'Admin role required to acknowledge D-ID MCP alerts'
      using errcode = '42501';
  end if;

  begin
    perform set_config('app.did_mcp_alert_ack_rpc', 'on', true);

    update public.did_mcp_alerts
    set acknowledged = true,
        acknowledged_by = v_uid,
        acknowledged_at = coalesce(acknowledged_at, timezone('utc', now()))
    where id = p_alert_id
    returning * into v_updated;

    perform set_config('app.did_mcp_alert_ack_rpc', 'off', true);
  exception
    when others then
      perform set_config('app.did_mcp_alert_ack_rpc', 'off', true);
      raise;
  end;

  if v_updated.id is null then
    raise exception 'Alert not found: %', p_alert_id
      using errcode = 'P0002';
  end if;

  return v_updated;
end;
$fn$;

revoke all on function public.acknowledge_did_mcp_alert(uuid) from public, anon;
grant execute on function public.acknowledge_did_mcp_alert(uuid) to authenticated;
grant execute on function public.acknowledge_did_mcp_alert(uuid) to service_role;
