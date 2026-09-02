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
    raise exception 'authorized video review contract failed: %', failure_message;
  end if;
end;
$$;

do $$
declare
  v_user uuid := '77777777-7777-4777-8777-777777777777';
  v_root_artifact uuid;
  v_root_review uuid;
  v_authorization uuid;
  v_job uuid;
  v_artifact uuid;
  v_review uuid;
  v_result jsonb;
  v_unauthorized_job uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  v_unauthorized_artifact uuid;
  v_blocked boolean := false;
begin
  insert into public.video_credit_accounts (user_id, available_credits)
  values (v_user, 600)
  on conflict (user_id) do update
  set available_credits = 600,
      reserved_credits = 0;

  select id into strict v_root_artifact
  from public.video_artifacts
  where job_id = '88888888-8888-4888-8888-888888888888';

  v_result := public.video_record_artifact_review(
    v_user,
    v_root_artifact,
    3::smallint,
    4::smallint,
    3::smallint,
    3::smallint,
    'improve',
    'Reusable office composition',
    'Stabilize the hand and document motion',
    'A fictional office worker handles one document with stable natural motion',
    'Root review for the authorized scheduler contract',
    'review_required',
    'review_required'
  );
  v_root_review := (v_result -> 'review' ->> 'id')::uuid;

  v_result := public.video_authorize_and_reserve_improvement(
    v_user,
    'authorized-review-contract',
    v_root_artifact,
    v_root_review,
    now() + interval '1 day',
    1::smallint,
    true,
    true,
    true,
    true
  );
  v_authorization := (v_result ->> 'authorization_id')::uuid;
  v_job := (v_result ->> 'job_id')::uuid;

  update public.video_generation_jobs
  set status = 'succeeded',
      reserved_credits = 0,
      charged_credits = 300,
      output_storage_path = v_user::text || '/' || v_job::text || '-attempt-1.mp4',
      completed_at = now()
  where id = v_job;

  select id into strict v_artifact
  from public.video_artifacts
  where job_id = v_job;

  v_result := public.video_record_authorized_artifact_review(
    v_user,
    v_authorization,
    v_artifact,
    4::smallint,
    5::smallint,
    4::smallint,
    4::smallint,
    'improve',
    'Prompt alignment and composition improved',
    'Remove the remaining hand jitter',
    'A fictional office worker closes a laptop with one smooth deliberate motion',
    'Cloud evidence reviewed by the scheduled improvement loop',
    'review_required',
    'review_required'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;

  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_artifacts as artifact
      join public.video_generation_jobs as job on job.id = artifact.job_id
      where artifact.id = v_artifact
        and artifact.latest_review_id = v_review
        and job.status = 'succeeded'
        and job.authorization_id = v_authorization
    ) and exists (
      select 1
      from public.video_artifact_reviews
      where id = v_review
        and artifact_id = v_artifact
        and decision = 'improve'
    ),
    'the exact authorized succeeded artifact must receive one append-only review'
  );

  begin
    perform public.video_record_authorized_artifact_review(
      v_user, v_authorization, v_artifact,
      4::smallint, 4::smallint, 4::smallint, 4::smallint,
      'keep', 'Duplicate', 'None', 'Duplicate review must be rejected',
      'Duplicate attempt', 'review_required', 'review_required'
    );
  exception when others then
    v_blocked := sqlerrm = 'video_authorized_review_artifact_already_reviewed';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'the scheduler must not append a second review to the same artifact'
  );

  insert into public.video_generation_jobs (
    id, user_id, idempotency_key, model_key, inference_engine, model_revision,
    prompt, duration_seconds, aspect_ratio, resolution, status,
    quoted_credits, reserved_credits, charged_credits, output_storage_path,
    completed_at
  ) values (
    v_unauthorized_job, v_user, 'unauthorized-review-contract',
    'studio-video-v1', 'omocha_works_gpu',
    'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e',
    'An unrelated generated clip', 5, '16:9', '720p', 'succeeded',
    300, 0, 300,
    v_user::text || '/' || v_unauthorized_job::text || '-attempt-1.mp4',
    now()
  );
  select id into strict v_unauthorized_artifact
  from public.video_artifacts
  where job_id = v_unauthorized_job;

  v_blocked := false;
  begin
    perform public.video_record_authorized_artifact_review(
      v_user, v_authorization, v_unauthorized_artifact,
      4::smallint, 4::smallint, 4::smallint, 4::smallint,
      'keep', 'Unrelated', 'None', 'Unrelated target must be rejected',
      'Mismatched authorization attempt', 'review_required', 'review_required'
    );
  exception when others then
    v_blocked := sqlerrm = 'video_authorized_review_target_invalid';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'an artifact outside the exact authorization must be rejected'
  );

  perform pg_temp.assert_true(
    has_function_privilege(
      'service_role',
      'public.video_record_authorized_artifact_review(uuid,uuid,uuid,smallint,smallint,smallint,smallint,text,text,text,text,text,text,text)',
      'EXECUTE'
    ) and not has_function_privilege(
      'authenticated',
      'public.video_record_authorized_artifact_review(uuid,uuid,uuid,smallint,smallint,smallint,smallint,text,text,text,text,text,text,text)',
      'EXECUTE'
    ),
    'only the service role may execute the bounded scheduler RPC'
  );
end;
$$;

rollback;