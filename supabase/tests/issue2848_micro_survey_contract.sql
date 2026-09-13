-- Issue #2848 runtime contract. Executed against the disposable integration DB.
begin;

insert into auth.users (id)
values
  ('00000000-0000-4000-8000-000000002848'::uuid),
  ('00000000-0000-4000-8000-000000012848'::uuid)
on conflict (id) do nothing;

do $contract$
begin
  if has_table_privilege('anon', 'public.micro_survey_preferences', 'select')
     or has_table_privilege('anon', 'public.micro_survey_responses', 'select')
     or has_table_privilege('anon', 'public.micro_survey_responses', 'insert') then
    raise exception 'anonymous micro-survey table access is not denied';
  end if;
  if has_table_privilege(
    'authenticated',
    'public.micro_survey_preferences',
    'insert,update,delete'
  ) then
    raise exception 'authenticated can bypass preference RPCs';
  end if;
  if has_table_privilege(
    'authenticated',
    'public.micro_survey_responses',
    'update'
  ) then
    raise exception 'micro-survey responses are unexpectedly mutable';
  end if;
  if has_function_privilege(
    'anon',
    'public.claim_micro_survey_prompt(text,text)',
    'execute'
  ) then
    raise exception 'anonymous can claim a micro-survey prompt';
  end if;
end;
$contract$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002848',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $user_one$
begin
  if not public.claim_micro_survey_prompt(
    'task_completion_v1',
    'resource_created'
  ) then
    raise exception 'first eligible prompt was not claimed';
  end if;
  if public.claim_micro_survey_prompt(
    'task_completion_v1',
    'resource_created'
  ) then
    raise exception '14-day cooldown allowed an immediate repeat';
  end if;

  insert into public.micro_survey_responses (
    user_id,
    survey_key,
    trigger,
    route,
    resource_type,
    completion_status,
    rating,
    comment
  ) values (
    auth.uid(),
    'task_completion_v1',
    'resource_created',
    '/team-workspace',
    'team',
    'succeeded',
    5,
    'short answer'
  );

  if (select count(*) from public.micro_survey_responses) is distinct from 1::bigint then
    raise exception 'owner cannot read the inserted response';
  end if;
end;
$user_one$;
reset role;

update public.micro_survey_preferences
set last_prompted_at = now() - interval '15 days',
    prompt_window_started_at = now() - interval '29 days',
    prompt_count_in_window = 1
where user_id = '00000000-0000-4000-8000-000000002848'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002848',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $frequency_cap$
begin
  if not public.claim_micro_survey_prompt(
    'task_completion_v1',
    'deployment_monitoring_created'
  ) then
    raise exception 'second prompt in rolling window was rejected';
  end if;
end;
$frequency_cap$;
reset role;

update public.micro_survey_preferences
set last_prompted_at = now() - interval '15 days'
where user_id = '00000000-0000-4000-8000-000000002848'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000002848',
  true
);
do $max_two$
begin
  if public.claim_micro_survey_prompt(
    'task_completion_v1',
    'resource_created'
  ) then
    raise exception 'rolling 30-day maximum allowed a third prompt';
  end if;
end;
$max_two$;
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000012848',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $user_two$
begin
  if (select count(*) from public.micro_survey_responses) is distinct from 0::bigint then
    raise exception 'RLS exposed another users response';
  end if;

  begin
    insert into public.micro_survey_responses (
      user_id,
      survey_key,
      trigger,
      route,
      resource_type,
      completion_status,
      rating
    ) values (
      '00000000-0000-4000-8000-000000002848'::uuid,
      'task_completion_v1',
      'resource_created',
      '/team-workspace',
      'team',
      'succeeded',
      1
    );
    raise exception 'cross-user response insert unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  perform public.set_micro_survey_opt_out(true);
  if public.claim_micro_survey_prompt(
    'task_completion_v1',
    'resource_created'
  ) then
    raise exception 'opted-out user received a prompt';
  end if;
end;
$user_two$;
reset role;

rollback;