-- Session hygiene for stale authenticated presence rows (#2910).
-- nocheck: time-relative
-- user_presence only has the generic updated_at trigger; this backfill does not
-- cross a date constraint and remains replay-safe as time advances.
-- Adds a 48h inactivity timeout, preserves invalidated rows briefly so the
-- client can request re-login, and schedules cleanup when pg_cron is available.
-- This is application presence hygiene; it does not revoke Supabase Auth
-- access or refresh tokens. The client signs out on its next presence sync.

alter table public.user_presence
  add column if not exists expires_at timestamptz,
  add column if not exists invalidated_at timestamptz,
  add column if not exists invalidation_reason text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_presence_invalidation_reason_check'
  ) then
    alter table public.user_presence
      add constraint user_presence_invalidation_reason_check
      check (
        invalidation_reason is null
        or invalidation_reason in ('idle_timeout', 'manual_cleanup')
      ) not valid;
  end if;
end $$;

update public.user_presence
set expires_at = coalesce(expires_at, last_seen + interval '48 hours')
where expires_at is null;

alter table public.user_presence
  alter column expires_at set default (now() + interval '48 hours');

create index if not exists idx_user_presence_expires_at
  on public.user_presence (expires_at)
  where invalidated_at is null;

create index if not exists idx_user_presence_invalidated_at
  on public.user_presence (invalidated_at)
  where invalidated_at is not null;

create or replace function public.cleanup_old_presence()
returns void
security definer
set search_path = public
as $$
begin
  update public.user_presence
  set expires_at = coalesce(expires_at, last_seen + interval '48 hours')
  where expires_at is null;

  update public.user_presence
  set
    is_online = false,
    invalidated_at = coalesce(invalidated_at, now()),
    invalidation_reason = coalesce(invalidation_reason, 'idle_timeout'),
    updated_at = now()
  where invalidated_at is null
    and (
      expires_at <= now()
      or last_seen < now() - interval '48 hours'
    );

  update public.user_presence
  set
    is_online = false,
    updated_at = now()
  where last_seen < now() - interval '5 minutes'
    and is_online = true;

  delete from public.user_presence
  where invalidated_at is not null
    and invalidated_at < now() - interval '7 days';

  delete from public.user_presence
  where last_seen < now() - interval '24 hours'
    and is_online = false
    and invalidated_at is null;

  delete from public.guest_presence
  where last_seen < now() - interval '30 minutes';
end;
$$ language plpgsql;

create or replace function public.get_session_hygiene_status(
  p_session_id text
)
returns jsonb
security definer
set search_path = public
as $$
declare
  v_presence public.user_presence%rowtype;
  v_now timestamptz := now();
  v_expires_at timestamptz;
begin
  if p_session_id is null or length(btrim(p_session_id)) = 0 then
    return jsonb_build_object(
      'status', 'unknown',
      'requires_relogin', false,
      'message', 'Session id is unavailable.'
    );
  end if;

  select *
  into v_presence
  from public.user_presence
  where session_id = p_session_id
    and (
      auth.uid() = user_id
      or auth.role() = 'service_role'
    )
  order by last_seen desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'status', 'unknown',
      'requires_relogin', false,
      'message', 'Session presence is not registered yet.'
    );
  end if;

  v_expires_at := coalesce(v_presence.expires_at, v_presence.last_seen + interval '48 hours');

  if v_presence.invalidated_at is not null then
    return jsonb_build_object(
      'status', 'invalidated',
      'requires_relogin', true,
      'message', 'Session expired. Please sign in again.',
      'expires_at', v_expires_at,
      'invalidated_at', v_presence.invalidated_at,
      'reason', coalesce(v_presence.invalidation_reason, 'idle_timeout')
    );
  end if;

  if v_expires_at <= v_now or v_presence.last_seen < v_now - interval '48 hours' then
    update public.user_presence
    set
      is_online = false,
      expires_at = v_expires_at,
      invalidated_at = v_now,
      invalidation_reason = 'idle_timeout',
      updated_at = v_now
    where id = v_presence.id;

    return jsonb_build_object(
      'status', 'expired',
      'requires_relogin', true,
      'message', 'Session expired. Please sign in again.',
      'expires_at', v_expires_at,
      'invalidated_at', v_now,
      'reason', 'idle_timeout'
    );
  end if;

  return jsonb_build_object(
    'status', 'active',
    'requires_relogin', false,
    'message', 'Session is active.',
    'expires_at', v_expires_at,
    'last_seen', v_presence.last_seen
  );
end;
$$ language plpgsql;

create or replace function public.get_session_hygiene_health()
returns jsonb
security definer
set search_path = public
as $$
declare
  v_expired_pending integer;
  v_invalidated integer;
  v_stale_online integer;
  v_guest_stale integer;
begin
  select count(*) into v_expired_pending
  from public.user_presence
  where invalidated_at is null
    and (
      coalesce(expires_at, last_seen + interval '48 hours') <= now()
      or last_seen < now() - interval '48 hours'
    );

  select count(*) into v_invalidated
  from public.user_presence
  where invalidated_at is not null;

  select count(*) into v_stale_online
  from public.user_presence
  where is_online = true
    and last_seen < now() - interval '5 minutes';

  select count(*) into v_guest_stale
  from public.guest_presence
  where last_seen < now() - interval '30 minutes';

  return jsonb_build_object(
    'status',
    case
      when v_expired_pending > 0 then 'degraded'
      else 'healthy'
    end,
    'expired_pending', v_expired_pending,
    'invalidated', v_invalidated,
    'stale_online', v_stale_online,
    'guest_stale', v_guest_stale,
    'timeout_hours', 48,
    'retention_days', 7
  );
end;
$$ language plpgsql;

revoke all on function public.cleanup_old_presence() from public, anon, authenticated;
revoke all on function public.get_session_hygiene_status(text) from public, anon;
revoke all on function public.get_session_hygiene_health() from public, anon, authenticated;

grant execute on function public.cleanup_old_presence() to service_role;
grant execute on function public.get_session_hygiene_status(text) to authenticated, service_role;
grant execute on function public.get_session_hygiene_health() to service_role;

do $$
declare
  v_job_id bigint;
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice 'pg_cron extension is not available in this environment.';
      return;
  end;

  select jobid into v_job_id
  from cron.job
  where jobname = 'session_hygiene_cleanup_hourly';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'session_hygiene_cleanup_hourly',
    '17 * * * *',
    $cmd$select public.cleanup_old_presence();$cmd$
  );
end $$;
