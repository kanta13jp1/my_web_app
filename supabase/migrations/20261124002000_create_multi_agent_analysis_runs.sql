-- Migration for Issue #2641: Role-split multi-agent sequential analysis runs & Human-in-the-Loop review

create table if not exists public.multi_agent_analysis_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  topic text not null
    check (char_length(trim(topic)) between 1 and 300),
  collector_output jsonb not null default '{}'::jsonb,
  calculator_output jsonb not null default '{}'::jsonb,
  synthesizer_output jsonb not null default '{}'::jsonb,
  reasoning_trace jsonb not null default '[]'::jsonb,
  human_review_status text not null default 'pending_human_review'
    check (
      human_review_status in (
        'pending_human_review',
        'approved',
        'rejected',
        'needs_revision'
      )
    ),
  human_review_note text not null default '',
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_multi_agent_analysis_runs_user_created
  on public.multi_agent_analysis_runs (user_id, created_at desc);

alter table public.multi_agent_analysis_runs enable row level security;

revoke all on table public.multi_agent_analysis_runs from public, anon;
grant select, insert, update, delete on table public.multi_agent_analysis_runs to authenticated;
grant all on table public.multi_agent_analysis_runs to service_role;

drop policy if exists "multi_agent_analysis_runs_select_own"
  on public.multi_agent_analysis_runs;
create policy "multi_agent_analysis_runs_select_own"
  on public.multi_agent_analysis_runs
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "multi_agent_analysis_runs_insert_own"
  on public.multi_agent_analysis_runs;
create policy "multi_agent_analysis_runs_insert_own"
  on public.multi_agent_analysis_runs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "multi_agent_analysis_runs_update_own"
  on public.multi_agent_analysis_runs;
create policy "multi_agent_analysis_runs_update_own"
  on public.multi_agent_analysis_runs
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "multi_agent_analysis_runs_delete_own"
  on public.multi_agent_analysis_runs;
create policy "multi_agent_analysis_runs_delete_own"
  on public.multi_agent_analysis_runs
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.guard_multi_agent_analysis_run_fields()
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
    nullif(auth.role(), ''),
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
    if new.human_review_status is distinct from 'pending_human_review'
       or new.reviewed_at is not null then
      raise exception 'New multi-agent analysis runs must start pending_human_review without reviewed_at'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if auth.uid() is null or old.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner may update only own multi-agent analysis run'
        using errcode = '42501';
    end if;
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Immutable identity and timestamp fields cannot be modified'
        using errcode = '42501';
    end if;
    new.updated_at := timezone('utc', now());
    if new.human_review_status = 'pending_human_review' then
      new.reviewed_at := null;
    elsif new.reviewed_at is null then
      new.reviewed_at := timezone('utc', now());
    end if;
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_multi_agent_analysis_run_fields
  on public.multi_agent_analysis_runs;
create trigger guard_multi_agent_analysis_run_fields
  before insert or update on public.multi_agent_analysis_runs
  for each row
  execute function public.guard_multi_agent_analysis_run_fields();

comment on table public.multi_agent_analysis_runs is
  'Stores sequential 3-agent JSON handoff outputs, reasoning traces, and mandatory Human-in-the-Loop review state (#2641).';
