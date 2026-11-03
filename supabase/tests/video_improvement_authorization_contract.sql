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
    raise exception 'video authorization contract failed: %', failure_message;
  end if;
end;
$$;

do $$
declare
  v_user uuid := '77777777-7777-4777-8777-777777777777';
  v_artifact uuid;
  v_review uuid;
  v_result jsonb;
  v_replay jsonb;
  v_authorization uuid;
  v_pending_authorization uuid;
  v_job uuid;
  v_retry_job uuid;
  v_blocked boolean := false;
begin
  insert into public.video_credit_accounts (user_id, available_credits)
  values (v_user, 400)
  on conflict (user_id) do update set available_credits = 400;

  select id into strict v_artifact
  from public.video_artifacts
  where job_id = '88888888-8888-4888-8888-888888888888';

  v_result := public.video_record_artifact_review(
    v_user,
    v_artifact,
    3::smallint,
    4::smallint,
    3::smallint,
    3::smallint,
    'improve',
    'The office composition is reusable',
    'Make the paper and hand motion more natural',
    'A fictional office worker reviews a document with stable natural hands',
    'Continue through the bounded improvement loop',
    'allowed',
    'cleared'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;

  v_result := public.video_authorize_and_reserve_improvement(
    v_user,
    'authorization-contract-1',
    v_artifact,
    v_review,
    now() + interval '7 days',
    2::smallint,
    true,
    true,
    true,
    true
  );
  v_authorization := (v_result ->> 'authorization_id')::uuid;
  v_job := (v_result ->> 'job_id')::uuid;

  perform pg_temp.assert_true(
    (v_result ->> 'available_credits')::bigint = 100
      and (v_result ->> 'reserved_credits')::bigint = 300
      and (v_result ->> 'authorization_remaining_credits')::bigint = 300
      and (v_result ->> 'authorization_remaining_regenerations')::integer = 1,
    'saving approval must reserve the first 300 credits in the same transaction'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_improvement_authorizations
      where id = v_authorization
        and user_id = v_user
        and status = 'active'
        and total_credit_limit = 600
        and consumed_regenerations = 1
        and reserved_credits = 300
        and not allow_credit_purchase
        and max_spend_jpy_total = 0
    ),
    'authorization must persist its expiry, iteration, credit, and no-purchase limits'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_generation_jobs
      where id = v_job
        and authorization_id = v_authorization
        and parent_artifact_id = v_artifact
        and applied_review_id = v_review
    ),
    'the first job must retain exact authorization and review lineage'
  );

  v_replay := public.video_authorize_and_reserve_improvement(
    v_user,
    'authorization-contract-1',
    v_artifact,
    v_review,
    now() + interval '7 days',
    2::smallint,
    true,
    true,
    true,
    true
  );
  perform pg_temp.assert_true(
    (v_replay ->> 'job_id')::uuid = v_job
      and (v_replay ->> 'authorization_id')::uuid = v_authorization
      and (v_replay ->> 'idempotent_replay')::boolean,
    'retrying the same request must not create another approval or reservation'
  );

  perform public.video_cancel_queued_generation(
    v_user,
    v_job,
    'generation_queue_unavailable'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_credit_accounts
      where user_id = v_user
        and available_credits = 400
        and reserved_credits = 0
    ) and exists (
      select 1
      from public.video_improvement_authorizations
      where id = v_authorization
        and status = 'active'
        and reserved_credits = 0
        and consumed_credits = 0
        and consumed_regenerations = 1
    ),
    'a failed wake must refund credits while still counting the bounded attempt'
  );

  v_result := public.video_reserve_authorized_improvement(
    v_user,
    v_authorization,
    v_artifact,
    v_review,
    'authorization-contract-2'
  );
  perform pg_temp.assert_true(
    v_result ->> 'job_id' is null
      and v_result ->> 'status' = 'pending_review'
      and v_result -> 'pending_reasons' ? 'review_consumed'
      and exists (
        select 1
        from public.video_improvement_authorizations
        where id = v_authorization
          and status = 'pending_review'
          and pending_reasons @> array['review_consumed']::text[]
      ),
    'an exact review is consumed once even when its queued job is refunded'
  );

  v_result := public.video_record_artifact_review(
    v_user,
    v_artifact,
    4::smallint,
    4::smallint,
    4::smallint,
    4::smallint,
    'improve',
    'The revised composition remains reusable',
    'Continue with a fresh exact review',
    'A fictional office worker handles one document with natural stable motion',
    'Fresh review for the second bounded attempt',
    'allowed',
    'cleared'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;

  v_result := public.video_reserve_authorized_improvement(
    v_user,
    v_authorization,
    v_artifact,
    v_review,
    'authorization-contract-3'
  );
  v_retry_job := (v_result ->> 'job_id')::uuid;
  perform pg_temp.assert_true(
    v_retry_job <> v_job
      and (v_result ->> 'available_credits')::bigint = 100
      and (v_result ->> 'reserved_credits')::bigint = 300
      and (v_result ->> 'authorization_remaining_regenerations')::integer = 0
      and exists (
        select 1
        from public.video_generation_jobs
        where id = v_retry_job
          and status = 'queued'
          and authorization_id = v_authorization
          and parent_artifact_id = v_artifact
          and applied_review_id = v_review
      ),
    'a fresh improve review may use the remaining bounded approval'
  );

  begin
    perform public.video_reserve_authorized_improvement(
      v_user,
      v_authorization,
      v_artifact,
      v_review,
      'authorization-contract-4'
    );
  exception when others then
    v_blocked := sqlerrm = 'video_authorization_exhausted';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'the recurring approval must stop after its configured attempt limit'
  );

  perform public.video_cancel_queued_generation(
    v_user,
    v_retry_job,
    'generation_queue_unavailable'
  );
  v_result := public.video_record_artifact_review(
    v_user,
    v_artifact,
    4::smallint,
    5::smallint,
    4::smallint,
    4::smallint,
    'improve',
    'The prompt alignment is now strong',
    'Fund one final fresh review when balance is available',
    'A fictional office worker closes a laptop with one smooth deliberate motion',
    'Pending authorization contract evidence',
    'allowed',
    'cleared'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;
  update public.video_credit_accounts
  set available_credits = 100,
      reserved_credits = 0
  where user_id = v_user;

  v_result := public.video_authorize_and_reserve_improvement(
    v_user,
    'authorization-pending-funding',
    v_artifact,
    v_review,
    now() + interval '7 days',
    2::smallint,
    true,
    true,
    true,
    true
  );
  v_pending_authorization := (v_result ->> 'authorization_id')::uuid;
  perform pg_temp.assert_true(
    v_result ->> 'job_id' is null
      and v_result ->> 'status' = 'pending_funding'
      and v_result -> 'pending_reasons' ? 'insufficient_credits'
      and (v_result ->> 'available_credits')::bigint = 100
      and (v_result ->> 'reserved_credits')::bigint = 0
      and exists (
        select 1
        from public.video_improvement_authorizations
        where id = v_pending_authorization
          and status = 'pending_funding'
          and request_idempotency_key = 'authorization-pending-funding'
          and consumed_regenerations = 0
          and reserved_credits = 0
      ),
    'a complete approval must persist without reserving when funds are short'
  );

  v_replay := public.video_authorize_and_reserve_improvement(
    v_user,
    'authorization-pending-funding',
    v_artifact,
    v_review,
    now() + interval '7 days',
    2::smallint,
    true,
    true,
    true,
    true
  );
  perform pg_temp.assert_true(
    (v_replay ->> 'authorization_id')::uuid = v_pending_authorization
      and v_replay ->> 'job_id' is null
      and (v_replay ->> 'idempotent_replay')::boolean,
    'replaying a pending request must not duplicate approval or reservation'
  );

  perform pg_temp.assert_true(
    has_table_privilege(
      'authenticated',
      'public.video_improvement_authorizations',
      'SELECT'
    ) and not has_table_privilege(
      'authenticated',
      'public.video_improvement_authorizations',
      'INSERT'
    ) and not has_function_privilege(
      'authenticated',
      'public.video_authorize_and_reserve_improvement(uuid,text,uuid,uuid,timestamptz,smallint,boolean,boolean,boolean,boolean)',
      'EXECUTE'
    ),
    'browser clients may read owned approvals but cannot mint or consume them directly'
  );
end;
$$;

rollback;
