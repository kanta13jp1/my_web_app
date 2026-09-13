-- Issue #2848: contextual micro-surveys after successful product tasks.
-- Purpose: product experience improvement only.
-- Data minimization: identifiers, names, user-entered task content, IPs, and
-- secrets are deliberately absent. Responses expire after 90 days.

create table if not exists public.micro_survey_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  opted_out boolean not null default false,
  last_prompted_at timestamptz,
  prompt_window_started_at timestamptz,
  prompt_count_in_window smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint micro_survey_preferences_prompt_count_check
    check (prompt_count_in_window between 0 and 2)
);

create table if not exists public.micro_survey_responses (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  survey_key text not null,
  trigger text not null,
  route text not null,
  resource_type text not null,
  completion_status text not null default 'succeeded',
  rating smallint not null,
  comment text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 days'),
  constraint micro_survey_responses_survey_key_check
    check (survey_key = 'task_completion_v1'),
  constraint micro_survey_responses_trigger_check
    check (trigger in ('deployment_monitoring_created', 'resource_created')),
  constraint micro_survey_responses_route_check
    check (route in ('/deployment-monitoring', '/team-workspace')),
  constraint micro_survey_responses_resource_type_check
    check (resource_type in ('deployment_monitoring_setup', 'team')),
  constraint micro_survey_responses_completion_status_check
    check (completion_status = 'succeeded'),
  constraint micro_survey_responses_rating_check
    check (rating between 1 and 5),
  constraint micro_survey_responses_comment_check
    check (comment is null or char_length(comment) between 1 and 280),
  constraint micro_survey_responses_retention_check
    check (expires_at > created_at and expires_at <= created_at + interval '90 days')
);

create index if not exists micro_survey_responses_user_created_idx
  on public.micro_survey_responses (user_id, created_at desc);
create index if not exists micro_survey_responses_expiry_idx
  on public.micro_survey_responses (expires_at);

alter table public.micro_survey_preferences enable row level security;
alter table public.micro_survey_responses enable row level security;

revoke all on table public.micro_survey_preferences from public, anon, authenticated;
revoke all on table public.micro_survey_responses from public, anon, authenticated;
revoke all on sequence public.micro_survey_responses_id_seq
  from public, anon, authenticated;

grant select on table public.micro_survey_preferences to authenticated;
grant select, delete on table public.micro_survey_responses to authenticated;
grant insert (
  user_id,
  survey_key,
  trigger,
  route,
  resource_type,
  completion_status,
  rating,
  comment
) on table public.micro_survey_responses to authenticated;
grant usage on sequence public.micro_survey_responses_id_seq to authenticated;

create policy micro_survey_preferences_select_own
on public.micro_survey_preferences
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy micro_survey_responses_select_own
on public.micro_survey_responses
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy micro_survey_responses_insert_own
on public.micro_survey_responses
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy micro_survey_responses_delete_own
on public.micro_survey_responses
for delete
to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.claim_micro_survey_prompt(
  p_survey_key text,
  p_trigger text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_now timestamptz := clock_timestamp();
  v_preference public.micro_survey_preferences%rowtype;
begin
  if v_user_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if p_survey_key is distinct from 'task_completion_v1'
     or p_trigger not in ('deployment_monitoring_created', 'resource_created') then
    raise invalid_parameter_value using message = 'unsupported micro-survey context';
  end if;

  insert into public.micro_survey_preferences (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select *
  into v_preference
  from public.micro_survey_preferences
  where user_id = v_user_id
  for update;

  if v_preference.opted_out then
    return false;
  end if;
  if v_preference.last_prompted_at is not null
     and v_preference.last_prompted_at > v_now - interval '14 days' then
    return false;
  end if;

  if v_preference.prompt_window_started_at is null
     or v_preference.prompt_window_started_at <= v_now - interval '30 days' then
    v_preference.prompt_window_started_at := v_now;
    v_preference.prompt_count_in_window := 0;
  elsif v_preference.prompt_count_in_window >= 2 then
    return false;
  end if;

  insert into public.micro_survey_preferences (
    user_id,
    last_prompted_at,
    prompt_window_started_at,
    prompt_count_in_window,
    updated_at
  ) values (
    v_user_id,
    v_now,
    v_preference.prompt_window_started_at,
    v_preference.prompt_count_in_window + 1,
    v_now
  )
  on conflict (user_id) do update
  set last_prompted_at = excluded.last_prompted_at,
      prompt_window_started_at = excluded.prompt_window_started_at,
      prompt_count_in_window = excluded.prompt_count_in_window,
      updated_at = excluded.updated_at;

  return true;
end;
$function$;

create or replace function public.set_micro_survey_opt_out(p_opted_out boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;

  insert into public.micro_survey_preferences (user_id, opted_out, updated_at)
  values (v_user_id, p_opted_out, clock_timestamp())
  on conflict (user_id) do update
  set opted_out = excluded.opted_out,
      updated_at = excluded.updated_at;
end;
$function$;

create or replace function public.purge_expired_micro_survey_responses()
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_deleted bigint;
begin
  delete from public.micro_survey_responses
  where expires_at <= clock_timestamp();
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$function$;

revoke all on function public.claim_micro_survey_prompt(text, text)
  from public, anon, authenticated;
revoke all on function public.set_micro_survey_opt_out(boolean)
  from public, anon, authenticated;
revoke all on function public.purge_expired_micro_survey_responses()
  from public, anon, authenticated;
grant execute on function public.claim_micro_survey_prompt(text, text)
  to authenticated;
grant execute on function public.set_micro_survey_opt_out(boolean)
  to authenticated;
grant execute on function public.purge_expired_micro_survey_responses()
  to service_role;

do $schedule$
begin
  if to_regprocedure('cron.schedule(text,text,text)') is not null then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'micro-survey-retention-cleanup';

    perform cron.schedule(
      'micro-survey-retention-cleanup',
      '17 3 * * *',
      'select public.purge_expired_micro_survey_responses();'
    );
  end if;
end;
$schedule$;