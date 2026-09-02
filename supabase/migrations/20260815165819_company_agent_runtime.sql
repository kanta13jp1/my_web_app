-- Durable AI Company Builder runtime, audit stream, and global kill switch.

create extension if not exists pgmq;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

alter table public.agent_tasks
  add column if not exists attempt_count integer not null default 0,
  add column if not exists started_at timestamptz,
  add column if not exists failed_at timestamptz,
  add column if not exists last_error text,
  add column if not exists result jsonb not null default '{}'::jsonb;

alter table public.agent_tasks
  drop constraint if exists agent_tasks_status_check;

alter table public.agent_tasks
  add constraint agent_tasks_status_check
  check (status in (
    'queued',
    'in_progress',
    'completed',
    'failed',
    'blocked',
    'cancelled'
  ));

alter table public.agent_tasks
  drop constraint if exists agent_tasks_attempt_count_check;

alter table public.agent_tasks
  add constraint agent_tasks_attempt_count_check
  check (attempt_count >= 0 and attempt_count <= 10);

create table if not exists public.company_agent_runtime_master_controls (
  user_id uuid primary key references auth.users(id) on delete cascade,
  kill_switch boolean not null default false,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_agent_runtime_controls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.hub_data(id) on delete cascade,
  state text not null default 'idle' check (
    state in ('idle', 'running', 'paused', 'completed', 'blocked', 'cancelled')
  ),
  kill_switch boolean not null default false,
  current_task_id uuid references public.agent_tasks(id) on delete set null,
  last_error text,
  started_at timestamptz,
  stopped_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, company_id)
);

create table if not exists public.company_agent_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.hub_data(id) on delete cascade,
  task_id uuid references public.agent_tasks(id) on delete set null,
  agent_id uuid references public.agents(id) on delete set null,
  event_type text not null,
  status text,
  provider text,
  model text,
  tier text,
  input_chars integer check (input_chars is null or input_chars >= 0),
  output_chars integer check (output_chars is null or output_chars >= 0),
  estimated_cost_usd numeric(14, 8) check (
    estimated_cost_usd is null or estimated_cost_usd >= 0
  ),
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists company_agent_runtime_controls_user_state_idx
  on public.company_agent_runtime_controls (user_id, state, updated_at desc);

create index if not exists company_agent_runtime_controls_task_idx
  on public.company_agent_runtime_controls (current_task_id)
  where current_task_id is not null;

create index if not exists company_agent_events_company_time_idx
  on public.company_agent_events (user_id, company_id, occurred_at desc);

create index if not exists company_agent_events_task_idx
  on public.company_agent_events (task_id, occurred_at desc)
  where task_id is not null;

create index if not exists agent_tasks_company_runtime_queue_idx
  on public.agent_tasks (
    user_id,
    ((metadata ->> 'company_id')),
    status,
    created_at
  )
  where source = 'company_builder_bootstrap';

drop trigger if exists trg_company_agent_runtime_master_updated_at
  on public.company_agent_runtime_master_controls;
create trigger trg_company_agent_runtime_master_updated_at
  before update on public.company_agent_runtime_master_controls
  for each row execute function public.set_agent_org_updated_at();

drop trigger if exists trg_company_agent_runtime_updated_at
  on public.company_agent_runtime_controls;
create trigger trg_company_agent_runtime_updated_at
  before update on public.company_agent_runtime_controls
  for each row execute function public.set_agent_org_updated_at();

alter table public.company_agent_runtime_master_controls enable row level security;
alter table public.company_agent_runtime_controls enable row level security;
alter table public.company_agent_events enable row level security;

drop policy if exists company_agent_runtime_master_select_own
  on public.company_agent_runtime_master_controls;
create policy company_agent_runtime_master_select_own
  on public.company_agent_runtime_master_controls
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists company_agent_runtime_controls_select_own
  on public.company_agent_runtime_controls;
create policy company_agent_runtime_controls_select_own
  on public.company_agent_runtime_controls
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists company_agent_events_select_own
  on public.company_agent_events;
create policy company_agent_events_select_own
  on public.company_agent_events
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.company_agent_runtime_master_controls
  from public, anon, authenticated;
revoke all on public.company_agent_runtime_controls
  from public, anon, authenticated;
revoke all on public.company_agent_events
  from public, anon, authenticated;
grant select on public.company_agent_runtime_master_controls to authenticated;
grant select on public.company_agent_runtime_controls to authenticated;
grant select on public.company_agent_events to authenticated;
grant all on public.company_agent_runtime_master_controls to service_role;
grant all on public.company_agent_runtime_controls to service_role;
grant all on public.company_agent_events to service_role;

with eligible_companies as materialized (
  select
    id as company_id,
    metadata,
    case
      when metadata ->> 'user_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        then (metadata ->> 'user_id')::uuid
      else null
    end as user_id
  from public.hub_data
  where source = 'company_builder_company'
)
insert into public.company_agent_runtime_master_controls (user_id)
select distinct company.user_id
from eligible_companies as company
join auth.users as owner on owner.id = company.user_id
where company.user_id is not null
on conflict (user_id) do nothing;

with eligible_companies as materialized (
  select
    id as company_id,
    metadata,
    case
      when metadata ->> 'user_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        then (metadata ->> 'user_id')::uuid
      else null
    end as user_id
  from public.hub_data
  where source = 'company_builder_company'
)
insert into public.company_agent_runtime_controls (
  user_id,
  company_id,
  state,
  last_error
)
select
  company.user_id,
  company.company_id,
  case when company.metadata ->> 'passed' = 'true' then 'idle' else 'blocked' end,
  case when company.metadata ->> 'passed' = 'true'
    then null
    else coalesce(
      company.metadata ->> 'recommendation',
      'Viability gate rejected'
    )
  end
from eligible_companies as company
join auth.users as owner on owner.id = company.user_id
where company.user_id is not null
on conflict (user_id, company_id) do nothing;

drop policy if exists "Agents update own org" on public.agents;
create policy "Agents update own org" on public.agents
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Agent tasks update own org" on public.agent_tasks;
create policy "Agent tasks update own org" on public.agent_tasks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Agent memories update own org" on public.agent_memories;
create policy "Agent memories update own org" on public.agent_memories
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

do $$
begin
  if to_regclass('pgmq.q_company_agent_runtime') is null then
    perform pgmq.create('company_agent_runtime');
  end if;
end;
$$;

create or replace function public.enqueue_company_agent_runtime(
  p_user_id uuid,
  p_company_id uuid,
  p_reason text default 'run'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message_id bigint;
begin
  if p_user_id is null or p_company_id is null then
    raise exception 'user_id and company_id are required';
  end if;

  if not exists (
    select 1
    from public.company_agent_runtime_controls
    where user_id = p_user_id and company_id = p_company_id
  ) then
    raise exception 'runtime control not found';
  end if;

  select message_id into v_message_id
  from pgmq.send(
    'company_agent_runtime',
    jsonb_build_object(
      'user_id', p_user_id,
      'company_id', p_company_id,
      'reason', left(coalesce(p_reason, 'run'), 80),
      'enqueued_at', now()
    ),
    0
  ) as message_id
  limit 1;

  return v_message_id;
end;
$$;

create or replace function public.read_company_agent_runtime(
  p_visibility_timeout integer default 120,
  p_limit integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_messages jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(message_row)), '[]'::jsonb)
  into v_messages
  from pgmq.read(
    'company_agent_runtime',
    greatest(30, least(coalesce(p_visibility_timeout, 120), 600)),
    greatest(1, least(coalesce(p_limit, 1), 10))
  ) as message_row;

  return v_messages;
end;
$$;

create or replace function public.archive_company_agent_runtime(
  p_message_id bigint
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select pgmq.archive('company_agent_runtime', p_message_id);
$$;

create or replace function public.dispatch_company_agent_runtime_worker()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id bigint;
  v_service_key text;
  v_supabase_url text := 'https://smmkxxavexumewbfaqpy.supabase.co';
begin
  if not exists (
    select 1
    from pgmq.q_company_agent_runtime
    where vt <= now()
  ) then
    return null;
  end if;

  begin
    select decrypted_secret
    into v_service_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;

    select coalesce(nullif(decrypted_secret, ''), v_supabase_url)
    into v_supabase_url
    from vault.decrypted_secrets
    where name in ('project_url', 'supabase_url')
    order by case name when 'project_url' then 0 else 1 end
    limit 1;
  exception when others then
    raise notice 'AI company runtime worker dispatch skipped: vault unavailable';
    return null;
  end;

  if nullif(v_service_key, '') is null then
    raise notice 'AI company runtime worker dispatch skipped: service_role_key missing';
    return null;
  end if;

  select net.http_post(
    url := rtrim(v_supabase_url, '/') || '/functions/v1/ai-hub',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_service_key,
      'apikey', v_service_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('action', 'company_builder.worker')
  ) into v_request_id;

  return v_request_id;
exception when others then
  raise notice 'AI company runtime worker dispatch failed: %', sqlerrm;
  return null;
end;
$$;

create or replace function public.claim_company_agent_task(
  p_user_id uuid,
  p_company_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.agent_tasks%rowtype;
  v_has_in_progress boolean := false;
  v_global_kill boolean := false;
begin
  select coalesce(kill_switch, false)
  into v_global_kill
  from public.company_agent_runtime_master_controls
  where user_id = p_user_id;

  if v_global_kill then
    return jsonb_build_object('task', null, 'state', 'cancelled');
  end if;

  perform 1
  from public.company_agent_runtime_controls
  where user_id = p_user_id
    and company_id = p_company_id
    and state = 'running'
    and kill_switch = false
  for update;

  if not found then
    return jsonb_build_object('task', null, 'state', 'inactive');
  end if;

  update public.agent_tasks
  set status = 'in_progress',
      attempt_count = attempt_count + 1,
      started_at = now(),
      failed_at = null,
      last_error = null
  where id = (
    select id
    from public.agent_tasks
    where user_id = p_user_id
      and source = 'company_builder_bootstrap'
      and metadata ->> 'company_id' = p_company_id::text
      and status = 'queued'
    order by
      case priority when 'high' then 0 when 'normal' then 1 else 2 end,
      created_at
    limit 1
    for update skip locked
  )
  returning * into v_task;

  if v_task.id is null then
    select exists (
      select 1
      from public.agent_tasks
      where user_id = p_user_id
        and source = 'company_builder_bootstrap'
        and metadata ->> 'company_id' = p_company_id::text
        and status = 'in_progress'
    ) into v_has_in_progress;

    if not v_has_in_progress then
      update public.company_agent_runtime_controls
      set state = 'completed',
          current_task_id = null,
          completed_at = now(),
          stopped_at = now()
      where user_id = p_user_id and company_id = p_company_id;

      insert into public.company_agent_events (
        user_id, company_id, event_type, status
      ) values (
        p_user_id, p_company_id, 'runtime_completed', 'completed'
      );
    end if;

    return jsonb_build_object(
      'task', null,
      'state', case when v_has_in_progress then 'running' else 'completed' end,
      'has_in_progress', v_has_in_progress
    );
  end if;

  update public.company_agent_runtime_controls
  set current_task_id = v_task.id,
      last_error = null
  where user_id = p_user_id and company_id = p_company_id;

  insert into public.company_agent_events (
    user_id,
    company_id,
    task_id,
    agent_id,
    event_type,
    status,
    payload
  ) values (
    p_user_id,
    p_company_id,
    v_task.id,
    v_task.assignee_agent_id,
    'task_started',
    'in_progress',
    jsonb_build_object(
      'title', v_task.title,
      'attempt_count', v_task.attempt_count,
      'stage', v_task.metadata ->> 'stage'
    )
  );

  return jsonb_build_object('task', to_jsonb(v_task), 'state', 'running');
end;
$$;

create or replace function public.finish_company_agent_task(
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
  v_task public.agent_tasks%rowtype;
  v_control public.company_agent_runtime_controls%rowtype;
  v_global_kill boolean := false;
  v_continue boolean := false;
  v_final_status text;
  v_event_type text;
begin
  select * into v_control
  from public.company_agent_runtime_controls
  where user_id = p_user_id and company_id = p_company_id
  for update;

  if v_control.id is null then
    raise exception 'runtime control not found';
  end if;

  select * into v_task
  from public.agent_tasks
  where id = p_task_id
    and user_id = p_user_id
    and metadata ->> 'company_id' = p_company_id::text
  for update;

  if v_task.id is null then
    raise exception 'runtime task not found';
  end if;

  select coalesce(kill_switch, false)
  into v_global_kill
  from public.company_agent_runtime_master_controls
  where user_id = p_user_id;

  if v_task.status = 'cancelled'
      or v_control.kill_switch
      or v_global_kill
      or v_control.state = 'cancelled' then
    v_final_status := 'cancelled';
    v_event_type := 'task_cancelled';
  elsif p_success then
    v_final_status := 'completed';
    v_event_type := 'task_completed';
  elsif v_task.attempt_count < 3 and v_control.state in ('running', 'paused') then
    v_final_status := 'queued';
    v_event_type := 'task_retry_scheduled';
  else
    v_final_status := 'failed';
    v_event_type := 'task_failed';
  end if;

  update public.agent_tasks
  set status = v_final_status,
      result = case when p_success then coalesce(p_result, '{}'::jsonb) else result end,
      completed_at = case when v_final_status = 'completed' then now() else null end,
      failed_at = case when v_final_status = 'failed' then now() else null end,
      last_error = case when p_success then null else left(coalesce(p_error, 'unknown error'), 1000) end
  where id = p_task_id;

  insert into public.company_agent_events (
    user_id,
    company_id,
    task_id,
    agent_id,
    event_type,
    status,
    provider,
    model,
    tier,
    input_chars,
    output_chars,
    estimated_cost_usd,
    duration_ms,
    payload
  ) values (
    p_user_id,
    p_company_id,
    p_task_id,
    v_task.assignee_agent_id,
    v_event_type,
    v_final_status,
    nullif(p_metrics ->> 'provider', ''),
    nullif(p_metrics ->> 'model', ''),
    nullif(p_metrics ->> 'tier', ''),
    nullif(p_metrics ->> 'input_chars', '')::integer,
    nullif(p_metrics ->> 'output_chars', '')::integer,
    nullif(p_metrics ->> 'estimated_cost_usd', '')::numeric,
    nullif(p_metrics ->> 'duration_ms', '')::integer,
    jsonb_build_object(
      'title', v_task.title,
      'attempt_count', v_task.attempt_count,
      'error', case when p_success then null else left(coalesce(p_error, ''), 500) end
    )
  );

  if v_final_status = 'failed' then
    update public.company_agent_runtime_controls
    set state = 'blocked',
        current_task_id = null,
        last_error = left(coalesce(p_error, 'Task failed'), 1000),
        stopped_at = now()
    where id = v_control.id;
  elsif v_control.state = 'running' and v_final_status <> 'cancelled' then
    select exists (
      select 1
      from public.agent_tasks
      where user_id = p_user_id
        and source = 'company_builder_bootstrap'
        and metadata ->> 'company_id' = p_company_id::text
        and status = 'queued'
    ) into v_continue;

    if v_continue then
      update public.company_agent_runtime_controls
      set current_task_id = null,
          last_error = case when p_success then null else left(coalesce(p_error, ''), 1000) end
      where id = v_control.id;
    else
      update public.company_agent_runtime_controls
      set state = 'completed',
          current_task_id = null,
          completed_at = now(),
          stopped_at = now(),
          last_error = null
      where id = v_control.id;

      insert into public.company_agent_events (
        user_id, company_id, event_type, status
      ) values (
        p_user_id, p_company_id, 'runtime_completed', 'completed'
      );
    end if;
  else
    update public.company_agent_runtime_controls
    set current_task_id = null
    where id = v_control.id;
  end if;

  select state into v_final_status
  from public.company_agent_runtime_controls
  where id = v_control.id;

  return jsonb_build_object(
    'state', v_final_status,
    'task_status', (
      select status from public.agent_tasks where id = p_task_id
    ),
    'continue', v_continue
  );
end;
$$;

create or replace function public.set_company_agent_runtime_state(
  p_user_id uuid,
  p_company_id uuid,
  p_command text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control public.company_agent_runtime_controls%rowtype;
  v_global_kill boolean := false;
  v_event_type text;
begin
  select coalesce(kill_switch, false)
  into v_global_kill
  from public.company_agent_runtime_master_controls
  where user_id = p_user_id;

  select * into v_control
  from public.company_agent_runtime_controls
  where user_id = p_user_id and company_id = p_company_id
  for update;

  if v_control.id is null then
    raise exception 'runtime control not found';
  end if;

  case lower(coalesce(p_command, ''))
    when 'start' then
      if v_global_kill then
        raise exception 'global kill switch is enabled';
      end if;
      update public.company_agent_runtime_controls
      set state = 'running',
          kill_switch = false,
          started_at = coalesce(started_at, now()),
          stopped_at = null,
          completed_at = null,
          last_error = null
      where id = v_control.id;
      v_event_type := 'runtime_started';
    when 'pause' then
      update public.company_agent_runtime_controls
      set state = 'paused', stopped_at = now()
      where id = v_control.id and state = 'running';
      v_event_type := 'runtime_paused';
    when 'resume' then
      if v_global_kill then
        raise exception 'global kill switch is enabled';
      end if;
      update public.agent_tasks
      set status = 'queued',
          attempt_count = 0,
          failed_at = null,
          completed_at = null,
          last_error = null
      where user_id = p_user_id
        and source = 'company_builder_bootstrap'
        and metadata ->> 'company_id' = p_company_id::text
        and status in ('failed', 'blocked', 'cancelled');
      update public.company_agent_runtime_controls
      set state = 'running',
          kill_switch = false,
          stopped_at = null,
          completed_at = null,
          last_error = null
      where id = v_control.id;
      v_event_type := 'runtime_resumed';
    when 'stop' then
      update public.agent_tasks
      set status = 'cancelled',
          completed_at = null,
          last_error = 'Stopped by the company runtime kill switch'
      where user_id = p_user_id
        and source = 'company_builder_bootstrap'
        and metadata ->> 'company_id' = p_company_id::text
        and status in ('queued', 'in_progress', 'failed', 'blocked');
      update public.company_agent_runtime_controls
      set state = 'cancelled',
          kill_switch = true,
          current_task_id = null,
          stopped_at = now(),
          last_error = 'Stopped by the company runtime kill switch'
      where id = v_control.id;
      v_event_type := 'runtime_cancelled';
    else
      raise exception 'unsupported runtime command';
  end case;

  insert into public.company_agent_events (
    user_id, company_id, event_type, status, payload
  )
  select
    p_user_id,
    p_company_id,
    v_event_type,
    state,
    jsonb_build_object('command', lower(p_command))
  from public.company_agent_runtime_controls
  where id = v_control.id;

  return (
    select to_jsonb(control_row)
    from public.company_agent_runtime_controls as control_row
    where id = v_control.id
  );
end;
$$;

create or replace function public.set_company_agent_global_kill_switch(
  p_user_id uuid,
  p_enabled boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_controls integer := 0;
  v_tasks integer := 0;
begin
  insert into public.company_agent_runtime_master_controls (
    user_id, kill_switch, reason
  ) values (
    p_user_id, p_enabled, left(p_reason, 500)
  )
  on conflict (user_id) do update
  set kill_switch = excluded.kill_switch,
      reason = excluded.reason;

  update public.company_agent_runtime_controls
  set kill_switch = p_enabled,
      state = case when p_enabled then 'cancelled' else state end,
      current_task_id = case when p_enabled then null else current_task_id end,
      stopped_at = case when p_enabled then now() else stopped_at end,
      last_error = case
        when p_enabled then coalesce(left(p_reason, 1000), 'Global kill switch enabled')
        else last_error
      end
  where user_id = p_user_id;
  get diagnostics v_controls = row_count;

  if p_enabled then
    update public.agent_tasks
    set status = 'cancelled',
        completed_at = null,
        last_error = coalesce(left(p_reason, 1000), 'Global kill switch enabled')
    where user_id = p_user_id
      and source = 'company_builder_bootstrap'
      and status in ('queued', 'in_progress', 'failed', 'blocked');
    get diagnostics v_tasks = row_count;
  end if;

  insert into public.company_agent_events (
    user_id, company_id, event_type, status, payload
  )
  select
    p_user_id,
    company_id,
    case when p_enabled
      then 'global_kill_switch_enabled'
      else 'global_kill_switch_reset'
    end,
    state,
    jsonb_build_object('enabled', p_enabled, 'reason', left(p_reason, 500))
  from public.company_agent_runtime_controls
  where user_id = p_user_id;

  return jsonb_build_object(
    'enabled', p_enabled,
    'affected_controls', v_controls,
    'cancelled_tasks', v_tasks
  );
end;
$$;

revoke execute on function public.enqueue_company_agent_runtime(uuid, uuid, text)
  from public, anon, authenticated;
revoke execute on function public.read_company_agent_runtime(integer, integer)
  from public, anon, authenticated;
revoke execute on function public.archive_company_agent_runtime(bigint)
  from public, anon, authenticated;
revoke execute on function public.dispatch_company_agent_runtime_worker()
  from public, anon, authenticated;
revoke execute on function public.claim_company_agent_task(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.finish_company_agent_task(uuid, uuid, uuid, boolean, jsonb, text, jsonb)
  from public, anon, authenticated;
revoke execute on function public.set_company_agent_runtime_state(uuid, uuid, text)
  from public, anon, authenticated;
revoke execute on function public.set_company_agent_global_kill_switch(uuid, boolean, text)
  from public, anon, authenticated;

grant execute on function public.enqueue_company_agent_runtime(uuid, uuid, text)
  to service_role;
grant execute on function public.read_company_agent_runtime(integer, integer)
  to service_role;
grant execute on function public.archive_company_agent_runtime(bigint)
  to service_role;
grant execute on function public.dispatch_company_agent_runtime_worker()
  to service_role;
grant execute on function public.claim_company_agent_task(uuid, uuid)
  to service_role;
grant execute on function public.finish_company_agent_task(uuid, uuid, uuid, boolean, jsonb, text, jsonb)
  to service_role;
grant execute on function public.set_company_agent_runtime_state(uuid, uuid, text)
  to service_role;
grant execute on function public.set_company_agent_global_kill_switch(uuid, boolean, text)
  to service_role;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'company_agent_runtime_worker_1m'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'company_agent_runtime_worker_1m',
    '* * * * *',
    $command$select public.dispatch_company_agent_runtime_worker();$command$
  );
exception when others then
  raise notice 'AI company runtime recovery schedule unavailable: %', sqlerrm;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'company_agent_runtime_master_controls'
  ) then
    alter publication supabase_realtime
      add table public.company_agent_runtime_master_controls;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'company_agent_runtime_controls'
  ) then
    alter publication supabase_realtime
      add table public.company_agent_runtime_controls;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'company_agent_events'
  ) then
    alter publication supabase_realtime
      add table public.company_agent_events;
  end if;
end;
$$;

comment on table public.company_agent_runtime_master_controls is
  'Per-user global kill switch for all AI Company Builder runtimes';
comment on table public.company_agent_runtime_controls is
  'Durable state machine for each AI Company Builder company runtime';
comment on table public.company_agent_events is
  'Immutable Realtime event and cost stream for AI Company Builder runs';
