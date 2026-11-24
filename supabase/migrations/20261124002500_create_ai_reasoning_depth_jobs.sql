-- Migration for Issue #2654: AI Reasoning Depth Switcher (Standard / Deep Research / Background)

create table if not exists public.ai_reasoning_depth_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reasoning_mode text not null default 'standard'
    check (reasoning_mode in ('standard', 'deep_research', 'background')),
  prompt_summary text not null
    check (char_length(trim(prompt_summary)) between 1 and 500),
  max_tool_calls integer not null default 3
    check (max_tool_calls between 1 and 50),
  timeout_seconds integer not null default 15
    check (timeout_seconds between 5 and 600),
  estimated_cost_usd numeric(10,6) not null default 0
    check (estimated_cost_usd >= 0),
  estimated_latency_ms integer not null default 1500
    check (estimated_latency_ms >= 0),
  tool_calls_completed integer not null default 0
    check (tool_calls_completed >= 0),
  job_status text not null default 'queued'
    check (job_status in ('queued', 'running', 'completed', 'failed', 'cancelled')),
  progress_note text not null default '',
  result_summary text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_reasoning_depth_jobs_user_created
  on public.ai_reasoning_depth_jobs (user_id, created_at desc);

create index if not exists idx_ai_reasoning_depth_jobs_user_status_updated
  on public.ai_reasoning_depth_jobs (user_id, job_status, updated_at desc);

alter table public.ai_reasoning_depth_jobs enable row level security;

revoke all on table public.ai_reasoning_depth_jobs from public, anon;
grant select, insert, update, delete on table public.ai_reasoning_depth_jobs to authenticated;
grant all on table public.ai_reasoning_depth_jobs to service_role;

drop policy if exists "ai_reasoning_depth_jobs_select_own"
  on public.ai_reasoning_depth_jobs;
create policy "ai_reasoning_depth_jobs_select_own"
  on public.ai_reasoning_depth_jobs
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "ai_reasoning_depth_jobs_insert_own"
  on public.ai_reasoning_depth_jobs;
create policy "ai_reasoning_depth_jobs_insert_own"
  on public.ai_reasoning_depth_jobs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "ai_reasoning_depth_jobs_update_own"
  on public.ai_reasoning_depth_jobs;
create policy "ai_reasoning_depth_jobs_update_own"
  on public.ai_reasoning_depth_jobs
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "ai_reasoning_depth_jobs_delete_own"
  on public.ai_reasoning_depth_jobs;
create policy "ai_reasoning_depth_jobs_delete_own"
  on public.ai_reasoning_depth_jobs
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.guard_ai_reasoning_depth_job_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $guard$
declare
  jwt_role text;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on insert'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if auth.uid() is null or old.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner may update only own reasoning depth job'
        using errcode = '42501';
    end if;
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Immutable identity and timestamp fields cannot be modified'
        using errcode = '42501';
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_ai_reasoning_depth_job_fields
  on public.ai_reasoning_depth_jobs;
create trigger guard_ai_reasoning_depth_job_fields
  before insert or update on public.ai_reasoning_depth_jobs
  for each row
  execute function public.guard_ai_reasoning_depth_job_fields();

comment on table public.ai_reasoning_depth_jobs is
  'Stores AI reasoning depth execution mode (standard / deep_research / background), USD cost/latency estimates, and async polling queue status (#2654).';
