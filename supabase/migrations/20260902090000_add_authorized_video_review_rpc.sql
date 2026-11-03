create or replace function public.video_record_authorized_artifact_review(
  p_user_id uuid,
  p_authorization_id uuid,
  p_artifact_id uuid,
  p_quality_score smallint,
  p_prompt_alignment_score smallint,
  p_motion_quality_score smallint,
  p_commercial_value_score smallint,
  p_decision text,
  p_strengths text,
  p_improvement_request text,
  p_suggested_prompt text,
  p_notes text,
  p_rights_status text,
  p_privacy_status text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_improvement_authorizations%rowtype;
  v_artifact public.video_artifacts%rowtype;
  v_job public.video_generation_jobs%rowtype;
begin
  select * into v_authorization
  from public.video_improvement_authorizations
  where id = p_authorization_id
    and user_id = p_user_id;
  if not found then
    raise exception 'video_authorization_not_found' using errcode = 'P0001';
  end if;

  select * into v_artifact
  from public.video_artifacts
  where id = p_artifact_id
    and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_artifact_not_found' using errcode = 'P0001';
  end if;
  if v_artifact.latest_review_id is not null then
    raise exception 'video_authorized_review_artifact_already_reviewed'
      using errcode = 'P0001';
  end if;

  select * into v_job
  from public.video_generation_jobs
  where id = v_artifact.job_id
    and user_id = p_user_id;
  if not found
    or v_job.status <> 'succeeded'
    or v_job.output_storage_path is null
    or v_job.authorization_id is distinct from p_authorization_id
  then
    raise exception 'video_authorized_review_target_invalid'
      using errcode = 'P0001';
  end if;

  return public.video_record_artifact_review(
    p_user_id,
    p_artifact_id,
    p_quality_score,
    p_prompt_alignment_score,
    p_motion_quality_score,
    p_commercial_value_score,
    p_decision,
    p_strengths,
    p_improvement_request,
    p_suggested_prompt,
    p_notes,
    p_rights_status,
    p_privacy_status
  );
end;
$$;

revoke all on function public.video_record_authorized_artifact_review(
  uuid, uuid, uuid, smallint, smallint, smallint, smallint,
  text, text, text, text, text, text, text
) from public, anon, authenticated;

grant execute on function public.video_record_authorized_artifact_review(
  uuid, uuid, uuid, smallint, smallint, smallint, smallint,
  text, text, text, text, text, text, text
) to service_role;

comment on function public.video_record_authorized_artifact_review(
  uuid, uuid, uuid, smallint, smallint, smallint, smallint,
  text, text, text, text, text, text, text
) is
  'Append one scheduler review only for an unreviewed artifact produced by a succeeded job under the exact owner authorization.';
