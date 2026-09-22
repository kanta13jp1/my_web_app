-- Recover AI Company Builder tasks whose worker disappeared or exceeded its lease.
-- Provider calls already have short AbortController budgets; this database watchdog
-- closes the remaining gap where an Edge worker exits after claiming a task.
-- nocheck: time-relative -- agent_tasks only has the benign updated_at=now() trigger;
-- the backfill and watchdog intentionally use current time to establish/expire leases.

alter table public.agent_tasks
  add column if not exists runtime_deadline_at timestamptz,
  add column if not exists timed_out_at timestamptz;

create index if not exists agent_tasks_company_runtime_deadline_idx
  on public.agent_tasks (runtime_deadline_at)
  where source = 'company_builder_bootstrap'
    and status = 'in_progress';

create or replace function public.stamp_company_agent_task_runtime_deadline()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.source = 'company_builder_bootstrap'
      and new.status = 'in_progress' then
    if tg_op = 'INSERT' then
      new.started_at := coalesce(new.started_at, now());
      new.runtime_deadline_at := new.started_at + interval '5 minutes';
      new.timed_out_at := null;
    elsif old.status is distinct from 'in_progress'
        or new.runtime_deadline_at is null then
      new.started_at := coalesce(new.started_at, now());
      new.runtime_deadline_at := new.started_at + interval '5 minutes';
      new.timed_out_at := null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_company_agent_task_runtime_deadline
  on public.agent_tasks;
create trigger trg_company_agent_task_runtime_deadline
  before insert or update of status, started_at on public.agent_tasks
  for each row execute function public.stamp_company_agent_task_runtime_deadline();

-- Give tasks that were already running during deployment the same bounded lease.
update public.agent_tasks
set runtime_deadline_at = coalesce(started_at, updated_at, created_at, now())
    + interval '5 minutes'
where source = 'company_builder_bootstrap'
  and status = 'in_progress'
  and runtime_deadline_at is null;

create or replace function public.expire_stale_company_agent_tasks()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expired integer := 0;
begin
  with stale_tasks as materialized (
    select
      task.id,
      task.user_id,
      task.assignee_agent_id,
      task.title,
      task.runtime_deadline_at,
      runtime.company_id,
      least(
        round(
          extract(epoch from (now() - coalesce(task.started_at, task.updated_at)))
          * 1000
        )::bigint,
        2147483647::bigint
      )::integer as duration_ms
    from public.agent_tasks as task
    join public.company_agent_runtime_controls as runtime
      on runtime.user_id = task.user_id
     and runtime.current_task_id = task.id
    where task.source = 'company_builder_bootstrap'
      and task.status = 'in_progress'
      and task.runtime_deadline_at <= now()
    for update of task skip locked
  ),
  expired_tasks as (
    update public.agent_tasks as task
    set status = 'failed',
        failed_at = now(),
        timed_out_at = now(),
        last_error = 'Agent runtime exceeded the five-minute deadline'
    from stale_tasks as stale
    where task.id = stale.id
    returning
      task.id,
      task.user_id,
      task.assignee_agent_id,
      task.title,
      task.runtime_deadline_at,
      stale.company_id,
      stale.duration_ms
  ),
  blocked_controls as (
    update public.company_agent_runtime_controls as runtime
    set state = 'blocked',
        current_task_id = null,
        stopped_at = now(),
        last_error = 'Agent runtime exceeded the five-minute deadline'
    from expired_tasks as task
    where runtime.user_id = task.user_id
      and runtime.company_id = task.company_id
      and runtime.current_task_id = task.id
    returning runtime.id
  ),
  logged_events as (
    insert into public.company_agent_events (
      user_id,
      company_id,
      task_id,
      agent_id,
      event_type,
      status,
      duration_ms,
      payload
    )
    select
      task.user_id,
      task.company_id,
      task.id,
      task.assignee_agent_id,
      'task_timed_out',
      'failed',
      task.duration_ms,
      jsonb_build_object(
        'title', task.title,
        'deadline_at', task.runtime_deadline_at,
        'timeout_seconds', 300,
        'error', 'Agent runtime exceeded the five-minute deadline'
      )
    from expired_tasks as task
    returning 1
  )
  select count(*)::integer into v_expired from logged_events;

  return v_expired;
end;
$$;

revoke execute on function public.expire_stale_company_agent_tasks()
  from public, anon, authenticated;
grant execute on function public.expire_stale_company_agent_tasks()
  to service_role;

-- Keep a late worker result from resurrecting a task after the watchdog failed it.
alter function public.finish_company_agent_task(
  uuid, uuid, uuid, boolean, jsonb, text, jsonb
) rename to finish_company_agent_task_unchecked;

revoke all on function public.finish_company_agent_task_unchecked(
  uuid, uuid, uuid, boolean, jsonb, text, jsonb
) from public, anon, authenticated, service_role;

create function public.finish_company_agent_task(
  p_user_id uuid,
  p_company_id uuid,
  p_task_id uuid,
  p_success boolean,
  p_result jsonb default '{}'::jsonb,
  p_error text default null,
  p_metrics jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task_status text;
  v_timed_out_at timestamptz;
  v_runtime_state text;
begin
  select status, timed_out_at
  into v_task_status, v_timed_out_at
  from public.agent_tasks
  where id = p_task_id
    and user_id = p_user_id
    and metadata ->> 'company_id' = p_company_id::text
  for update;

  if v_timed_out_at is not null then
    select state into v_runtime_state
    from public.company_agent_runtime_controls
    where user_id = p_user_id and company_id = p_company_id;

    insert into public.company_agent_events (
      user_id, company_id, task_id, event_type, status, payload
    ) values (
      p_user_id,
      p_company_id,
      p_task_id,
      'task_late_result_discarded',
      'failed',
      jsonb_build_object(
        'timed_out_at', v_timed_out_at,
        'worker_reported_success', p_success,
        'error', left(coalesce(p_error, ''), 500)
      )
    );

    return jsonb_build_object(
      'state', coalesce(v_runtime_state, 'blocked'),
      'task_status', v_task_status,
      'continue', false,
      'timed_out', true
    );
  end if;

  return public.finish_company_agent_task_unchecked(
    p_user_id,
    p_company_id,
    p_task_id,
    p_success,
    p_result,
    p_error,
    p_metrics
  );
end;
$$;

revoke execute on function public.finish_company_agent_task(
  uuid, uuid, uuid, boolean, jsonb, text, jsonb
) from public, anon, authenticated;
grant execute on function public.finish_company_agent_task(
  uuid, uuid, uuid, boolean, jsonb, text, jsonb
) to service_role;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'company_agent_runtime_watchdog_1m'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'company_agent_runtime_watchdog_1m',
    '* * * * *',
    $command$select public.expire_stale_company_agent_tasks();$command$
  );
exception when others then
  raise notice 'AI company runtime watchdog schedule unavailable: %', sqlerrm;
end;
$$;

comment on function public.expire_stale_company_agent_tasks() is
  'Fails AI Company Builder tasks after their five-minute lease and emits an audit event';
