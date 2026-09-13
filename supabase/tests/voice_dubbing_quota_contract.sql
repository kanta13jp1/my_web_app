-- Runtime contract for the Issue #1202 quota/job state machine. Any mismatch
-- raises and fails the Testcontainers smoke transaction.
do $contract$
declare
  v_user constant uuid := '00000000-0000-4000-8000-000000001202';
  v_failed_request constant uuid := '00000000-0000-4000-8000-000000001211';
  v_completed_request constant uuid := '00000000-0000-4000-8000-000000001212';
  v_expired_request constant uuid := '00000000-0000-4000-8000-000000001213';
  v_over_limit_request constant uuid := '00000000-0000-4000-8000-000000001214';
  v_hash_a constant text := pg_catalog.repeat('a', 64);
  v_hash_b constant text := pg_catalog.repeat('b', 64);
  v_hash_c constant text := pg_catalog.repeat('c', 64);
  v_hash_d constant text := pg_catalog.repeat('d', 64);
  v_claim jsonb;
  v_finish jsonb;
  v_recovered bigint;
  v_counter record;
  v_job record;
  v_signature text;
begin
  foreach v_signature in array array[
    'public.claim_voice_character_quota(uuid,uuid,text,integer)',
    'public.reconcile_voice_dubbing_quota(uuid)',
    'public.start_voice_dubbing_chunk(uuid,uuid,integer)',
    'public.finish_voice_dubbing_job(uuid,uuid,text,integer,jsonb,text)'
  ] loop
    if pg_catalog.has_function_privilege(
      'authenticated',
      v_signature,
      'EXECUTE'
    ) then
      raise exception 'authenticated can execute %', v_signature;
    end if;
    if not pg_catalog.has_function_privilege(
      'service_role',
      v_signature,
      'EXECUTE'
    ) then
      raise exception 'service_role cannot execute %', v_signature;
    end if;
  end loop;
  if not exists (
    select 1
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'voice_dubbing_jobs'
      and relation.relrowsecurity
  ) then
    raise exception 'voice_dubbing_jobs RLS is disabled';
  end if;
  if pg_catalog.has_table_privilege(
    'authenticated',
    'public.voice_dubbing_jobs',
    'SELECT'
  ) then
    raise exception 'authenticated can select voice_dubbing_jobs';
  end if;
  if not pg_catalog.has_table_privilege(
    'service_role',
    'public.voice_dubbing_jobs',
    'SELECT'
  ) then
    raise exception 'service_role cannot select voice_dubbing_jobs';
  end if;

  insert into auth.users (id) values (v_user)
  on conflict (id) do nothing;
  delete from public.voice_dubbing_jobs where user_id = v_user;
  delete from public.billing_usage_counters where user_id = v_user;
  delete from public.billing_subscriptions where user_id = v_user;
  insert into public.billing_subscriptions (user_id, tier, status)
  values (v_user, 'free', 'active');

  select public.claim_voice_character_quota(
    v_user,
    v_failed_request,
    v_hash_a,
    100
  ) into v_claim;
  if (v_claim ->> 'allowed')::boolean is distinct from true
    or (v_claim ->> 'used')::bigint is distinct from 100::bigint
    or (v_claim ->> 'generation_count')::integer is distinct from 1
  then
    raise exception 'initial quota claim mismatch: %', v_claim;
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_failed_request,
    v_hash_a,
    100
  ) into v_claim;
  if v_claim ->> 'reason' is distinct from 'request_in_progress' then
    raise exception 'in-progress replay mismatch: %', v_claim;
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_failed_request,
    v_hash_b,
    100
  ) into v_claim;
  if v_claim ->> 'reason' is distinct from 'idempotency_conflict' then
    raise exception 'idempotency conflict mismatch: %', v_claim;
  end if;

  perform public.start_voice_dubbing_chunk(v_user, v_failed_request, 40);
  select public.finish_voice_dubbing_job(
    v_user,
    v_failed_request,
    'failed',
    40,
    null,
    'provider_failed'
  ) into v_finish;
  if v_finish ->> 'status' is distinct from 'failed'
    or (v_finish ->> 'released_characters')::integer is distinct from 60
  then
    raise exception 'failed finish mismatch: %', v_finish;
  end if;

  select status, reserved_characters, started_characters, billed_characters,
    released_characters
  into v_job
  from public.voice_dubbing_jobs
  where user_id = v_user and request_id = v_failed_request;
  if v_job.status is distinct from 'failed'
    or v_job.reserved_characters is distinct from 100
    or v_job.started_characters is distinct from 40
    or v_job.billed_characters is distinct from 40
    or v_job.released_characters is distinct from 60
  then
    raise exception 'failed job ledger mismatch: %', row_to_json(v_job);
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_failed_request,
    v_hash_a,
    100
  ) into v_claim;
  if v_claim ->> 'reason' is distinct from 'retry_with_new_request_id' then
    raise exception 'failed replay mismatch: %', v_claim;
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_completed_request,
    v_hash_b,
    50
  ) into v_claim;
  perform public.start_voice_dubbing_chunk(v_user, v_completed_request, 50);
  select public.finish_voice_dubbing_job(
    v_user,
    v_completed_request,
    'completed',
    50,
    '{"storage_path":"00000000-0000-4000-8000-000000001202/2026-08/result.mp3"}'::jsonb,
    null
  ) into v_finish;
  if v_finish ->> 'status' is distinct from 'completed' then
    raise exception 'completed finish mismatch: %', v_finish;
  end if;

  select public.finish_voice_dubbing_job(
    v_user,
    v_completed_request,
    'failed',
    50,
    null,
    'late_failure'
  ) into v_finish;
  if v_finish ->> 'status' is distinct from 'completed'
    or (v_finish ->> 'terminal_conflict')::boolean is distinct from true
  then
    raise exception 'terminal completion was overwritten: %', v_finish;
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_completed_request,
    v_hash_b,
    50
  ) into v_claim;
  if (v_claim ->> 'replayed')::boolean is distinct from true
    or v_claim #>> '{result,storage_path}' is distinct from
      '00000000-0000-4000-8000-000000001202/2026-08/result.mp3'
  then
    raise exception 'completed replay mismatch: %', v_claim;
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_expired_request,
    v_hash_c,
    70
  ) into v_claim;
  perform public.start_voice_dubbing_chunk(v_user, v_expired_request, 20);
  update public.voice_dubbing_jobs
  set expires_at = pg_catalog.now() - interval '1 second'
  where user_id = v_user and request_id = v_expired_request;
  select public.reconcile_voice_dubbing_quota(v_user) into v_recovered;
  if v_recovered is distinct from 50::bigint then
    raise exception 'TTL recovery mismatch: %', v_recovered;
  end if;

  select status, reserved_characters, started_characters, billed_characters,
    released_characters
  into v_job
  from public.voice_dubbing_jobs
  where user_id = v_user and request_id = v_expired_request;
  if v_job.status is distinct from 'expired'
    or v_job.reserved_characters is distinct from 70
    or v_job.started_characters is distinct from 20
    or v_job.billed_characters is distinct from 20
    or v_job.released_characters is distinct from 50
  then
    raise exception 'expired job ledger mismatch: %', row_to_json(v_job);
  end if;

  select voice_character_count, voice_generation_count
  into v_counter
  from public.billing_usage_counters
  where user_id = v_user
    and period_start = pg_catalog.date_trunc(
      'month',
      pg_catalog.timezone('UTC', pg_catalog.now())
    )::date;
  if v_counter.voice_character_count is distinct from 110::bigint
    or v_counter.voice_generation_count is distinct from 3
  then
    raise exception 'final usage counter mismatch: %', row_to_json(v_counter);
  end if;

  select public.claim_voice_character_quota(
    v_user,
    v_over_limit_request,
    v_hash_d,
    4900
  ) into v_claim;
  if (v_claim ->> 'allowed')::boolean is distinct from false
    or v_claim ->> 'reason' is distinct from 'voice_character_limit_reached'
    or exists (
      select 1
      from public.voice_dubbing_jobs
      where user_id = v_user and request_id = v_over_limit_request
    )
  then
    raise exception 'over-limit claim mismatch: %', v_claim;
  end if;
  select voice_character_count, voice_generation_count
  into v_counter
  from public.billing_usage_counters
  where user_id = v_user
    and period_start = pg_catalog.date_trunc(
      'month',
      pg_catalog.timezone('UTC', pg_catalog.now())
    )::date;
  if v_counter.voice_character_count is distinct from 110::bigint
    or v_counter.voice_generation_count is distinct from 3
  then
    raise exception 'over-limit claim changed usage: %', row_to_json(v_counter);
  end if;
end;
$contract$;
