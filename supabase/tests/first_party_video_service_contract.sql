begin;

create or replace function pg_temp.assert_true(
  condition boolean,
  failure_message text
)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition, false) then
    raise exception 'video contract failed: %', failure_message;
  end if;
end;
$$;

do $$
declare
  v_user uuid := '11111111-1111-4111-8111-111111111111';
  v_second_user uuid := '22222222-2222-4222-8222-222222222222';
  v_reserved jsonb;
  v_replay jsonb;
  v_claim jsonb;
  v_validation jsonb;
  v_result jsonb;
  v_job_id uuid;
  v_lease text;
  v_blocked boolean;
  v_available bigint;
  v_reserved_credits bigint;
  v_status text;
begin
  insert into auth.users (id) values (v_user), (v_second_user);

  perform public.video_grant_credit_pack(
    v_user, 'starter', 500, 500, 'cs_video_contract_1', 'pi_video_contract_1'
  );
  select available_credits, reserved_credits
  into v_available, v_reserved_credits
  from public.video_credit_accounts where user_id = v_user;
  perform pg_temp.assert_true(
    v_available = 500 and v_reserved_credits = 0,
    'credit pack must grant the exact server-defined balance'
  );

  v_reserved := public.video_reserve_generation(
    v_user,
    'contract-job-1',
    'studio-video-v1',
    'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'A paper city wakes at sunrise',
    5::smallint,
    '16:9',
    '720p',
    300::bigint
  );
  v_job_id := (v_reserved ->> 'job_id')::uuid;
  perform pg_temp.assert_true(
    (v_reserved ->> 'available_credits')::bigint = 200 and
      (v_reserved ->> 'reserved_credits')::bigint = 300,
    'reservation must atomically move available credits to reserved'
  );

  v_replay := public.video_reserve_generation(
    v_user,
    'contract-job-1',
    'studio-video-v1',
    'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'A paper city wakes at sunrise',
    5::smallint,
    '16:9',
    '720p',
    300::bigint
  );
  perform pg_temp.assert_true(
    (v_replay ->> 'job_id')::uuid = v_job_id and
      (v_replay ->> 'idempotent_replay')::boolean,
    'same idempotency key must not reserve twice'
  );

  v_blocked := false;
  begin
    perform public.video_reserve_generation(
      v_user,
      'contract-job-2',
      'studio-video-v1',
      'omocha_works_gpu',
      'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
      'A second paper city wakes at sunrise',
      5::smallint,
      '16:9',
      '720p',
      300::bigint
    );
  exception when others then
    v_blocked := sqlerrm = 'video_generation_already_active';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'a user must not hold multiple active reservations'
  );

  v_claim := public.video_claim_generation('gpu-contract-01', 300);
  v_lease := v_claim ->> 'lease_token';
  perform pg_temp.assert_true(
    (v_claim ->> 'job_id')::uuid = v_job_id and
      (v_claim ->> 'attempt')::integer = 1,
    'oldest queued job must receive a bounded first lease'
  );

  update public.video_generation_jobs
  set lease_expires_at = now() - interval '1 second'
  where id = v_job_id;
  perform pg_temp.assert_true(
    not public.video_heartbeat_generation(v_job_id, 'gpu-contract-01', v_lease, 300),
    'expired lease must not be revived by heartbeat'
  );
  perform pg_temp.assert_true(
    public.video_validate_generation_lease(v_job_id, 'gpu-contract-01', v_lease) is null,
    'expired lease must not prepare an upload'
  );

  v_blocked := false;
  begin
    perform public.video_complete_claimed_generation(
      v_job_id,
      'gpu-contract-01',
      v_lease,
      v_user::text || '/' || v_job_id::text || '-attempt-1.mp4'
    );
  exception when others then
    v_blocked := sqlerrm = 'invalid_worker_lease';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'expired lease must not settle a customer charge'
  );

  v_claim := public.video_claim_generation('gpu-contract-02', 300);
  v_lease := v_claim ->> 'lease_token';
  perform pg_temp.assert_true(
    (v_claim ->> 'attempt')::integer = 2,
    'expired job must be reclaimed with a new attempt'
  );
  perform pg_temp.assert_true(
    (v_claim -> 'cleanup_storage_paths') @> to_jsonb(array[
      v_user::text || '/' || v_job_id::text || '-attempt-1.mp4'
    ]),
    'reclaimed lease must schedule the abandoned attempt path for cleanup'
  );
  v_result := public.video_fail_claimed_generation(
    v_job_id, 'gpu-contract-02', v_lease, 'inference_failed', true
  );
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'queued' and
      (v_result ->> 'retry_scheduled')::boolean,
    'retryable failure must return the job to the queue'
  );

  v_claim := public.video_claim_generation('gpu-contract-03', 300);
  v_lease := v_claim ->> 'lease_token';
  perform public.video_fail_claimed_generation(
    v_job_id, 'gpu-contract-03', v_lease, 'output_invalid', false
  );
  select status into v_status
  from public.video_generation_jobs where id = v_job_id;
  select available_credits, reserved_credits
  into v_available, v_reserved_credits
  from public.video_credit_accounts where user_id = v_user;
  perform pg_temp.assert_true(
    v_status = 'failed' and v_available = 500 and v_reserved_credits = 0,
    'terminal failure must return the full reservation exactly once'
  );

  v_reserved := public.video_reserve_generation(
    v_user,
    'contract-cancel-1',
    'studio-video-v1',
    'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'A quiet forest under soft rain',
    5::smallint,
    '16:9',
    '720p',
    300::bigint
  );
  v_job_id := (v_reserved ->> 'job_id')::uuid;
  v_result := public.video_cancel_queued_generation(
    v_user, v_job_id, 'generation_queue_unavailable'
  );
  select available_credits, reserved_credits
  into v_available, v_reserved_credits
  from public.video_credit_accounts where user_id = v_user;
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'failed' and
      v_available = 500 and v_reserved_credits = 0,
    'wake failure must cancel an unclaimed job and immediately restore credits'
  );

  perform public.video_grant_credit_pack(
    v_second_user, 'starter', 500, 500, 'cs_video_contract_2', 'pi_video_contract_2'
  );
  v_reserved := public.video_reserve_generation(
    v_second_user,
    'contract-success-1',
    'studio-video-v1',
    'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'A calm ocean reflects the morning sky',
    5::smallint,
    '9:16',
    '720p',
    300::bigint
  );
  v_job_id := (v_reserved ->> 'job_id')::uuid;
  v_claim := public.video_claim_generation('gpu-contract-04', 300);
  v_lease := v_claim ->> 'lease_token';
  v_validation := public.video_validate_generation_lease(
    v_job_id, 'gpu-contract-04', v_lease
  );
  v_result := public.video_complete_claimed_generation(
    v_job_id,
    'gpu-contract-04',
    v_lease,
    v_validation ->> 'storage_path'
  );
  select available_credits, reserved_credits
  into v_available, v_reserved_credits
  from public.video_credit_accounts where user_id = v_second_user;
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'succeeded' and
      v_available = 200 and v_reserved_credits = 0,
    'successful completion must charge the reserved credits exactly once'
  );

  perform pg_temp.assert_true(
    (
      select file_size_limit = 52428800 and not public
      from storage.buckets where id = 'video-generations'
    ),
    'output bucket must remain private and bounded to 50 MB'
  );
  perform pg_temp.assert_true(
    has_column_privilege(
      'authenticated',
      'public.video_generation_jobs',
      'status',
      'SELECT'
    ) and
      not has_table_privilege('authenticated', 'public.video_generation_jobs', 'INSERT'),
    'authenticated users may read owned jobs but never mutate the queue'
  );
  perform pg_temp.assert_true(
    not has_function_privilege(
      'authenticated',
      'public.video_claim_generation(text,integer)',
      'EXECUTE'
    ) and has_function_privilege(
      'service_role',
      'public.video_claim_generation(text,integer)',
      'EXECUTE'
    ),
    'worker queue RPC must remain service-role-only'
  );
end;
$$;

rollback;
