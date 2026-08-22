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
    raise exception 'video artifact contract failed: %', failure_message;
  end if;
end;
$$;

do $$
declare
  v_user uuid := '77777777-7777-4777-8777-777777777777';
  v_job uuid := '88888888-8888-4888-8888-888888888888';
  v_child_job uuid := '99999999-9999-4999-8999-999999999999';
  v_artifact uuid;
  v_child_artifact uuid;
  v_review uuid;
  v_result jsonb;
  v_blocked boolean := false;
  v_count integer;
begin
  select id into strict v_artifact
  from public.video_artifacts
  where job_id = v_job;

  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_artifacts
      where id = v_artifact
        and lifecycle_stage = 'captured'
        and rights_status = 'review_required'
        and privacy_status = 'review_required'
        and commerce_status = 'sale_candidate'
        and intended_for_sale
    ),
    'a pre-migration success must become a private sale-candidate artifact'
  );

  select count(*) into v_count
  from public.video_artifact_events
  where artifact_id = v_artifact and event_type = 'captured';
  perform pg_temp.assert_true(
    v_count = 1,
    'capture evidence must be exactly-once during backfill'
  );

  v_result := public.video_record_artifact_review(
    v_user,
    v_artifact,
    4::smallint,
    4::smallint,
    3::smallint,
    4::smallint,
    'improve',
    'The composition is clear',
    'Make the hand movement more natural',
    'A designer works naturally in a bright office, stable hands',
    'Candidate for a business footage pack',
    'allowed',
    'cleared'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;

  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_artifacts
      where id = v_artifact
        and latest_review_id = v_review
        and lifecycle_stage = 'productizing'
        and rights_status = 'allowed'
        and privacy_status = 'cleared'
        and commerce_status = 'sale_candidate'
    ),
    'review must advance readiness without automatically listing the video'
  );

  insert into public.video_generation_jobs (
    id,
    user_id,
    idempotency_key,
    model_key,
    inference_engine,
    model_revision,
    prompt,
    duration_seconds,
    aspect_ratio,
    resolution,
    status,
    quoted_credits,
    reserved_credits
  )
  values (
    v_child_job,
    v_user,
    'artifact-child-contract',
    'studio-video-v1',
    'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'A designer works naturally in a bright office, stable hands',
    5,
    '16:9',
    '720p',
    'queued',
    300,
    300
  );

  perform public.video_link_generation_iteration(
    v_user,
    v_child_job,
    v_artifact,
    v_review
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_generation_jobs
      where id = v_child_job
        and parent_artifact_id = v_artifact
        and applied_review_id = v_review
    ),
    'the next paid job must retain the exact source artifact and review'
  );

  update public.video_generation_jobs
  set status = 'succeeded',
      reserved_credits = 0,
      charged_credits = 300,
      output_storage_path = v_user::text || '/' || v_child_job::text || '-attempt-1.mp4',
      completed_at = now()
  where id = v_child_job;

  select id into strict v_child_artifact
  from public.video_artifacts
  where job_id = v_child_job;
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_artifacts
      where id = v_child_artifact
        and parent_artifact_id = v_artifact
        and iteration = 2
    ),
    'a completed improvement must preserve its parent lineage'
  );

  begin
    update public.video_artifacts
    set storage_path = 'tampered.mp4'
    where id = v_artifact;
  exception when others then
    v_blocked := sqlerrm = 'video_artifact_original_is_immutable';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'the stored original path must be immutable'
  );

  perform pg_temp.assert_true(
    not has_table_privilege('authenticated', 'public.video_artifacts', 'INSERT')
      and not has_table_privilege(
        'authenticated',
        'public.video_artifact_reviews',
        'INSERT'
      ),
    'browser clients must not insert artifacts or reviews directly'
  );
  perform pg_temp.assert_true(
    not has_table_privilege(
      'service_role',
      'public.video_artifact_reviews',
      'UPDATE'
    )
      and not has_table_privilege(
        'service_role',
        'public.video_artifact_events',
        'DELETE'
      ),
    'review and lifecycle evidence must remain append-only'
  );
end;
$$;

rollback;
