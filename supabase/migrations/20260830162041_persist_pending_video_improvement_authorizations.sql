-- Persist a complete recurring-improvement approval even when the first
-- reservation cannot run yet. Pending approvals never reserve credits or
-- create GPU jobs; they can be resumed later through the same guarded RPC.
-- nocheck: time-relative -- only video improvement authorization state is
-- updated and all financial mutations remain inside the reservation RPCs.

alter table public.video_improvement_authorizations
  drop constraint video_improvement_authorizations_status_check;

alter table public.video_improvement_authorizations
  add column request_idempotency_key text,
  add column pending_reasons text[] not null default '{}'::text[],
  add column last_reservation_attempt_at timestamptz;

update public.video_improvement_authorizations
set request_idempotency_key = 'legacy_' || replace(id::text, '-', '')
where request_idempotency_key is null;

alter table public.video_improvement_authorizations
  alter column request_idempotency_key set not null,
  add constraint video_improvement_authorizations_status_check check (
    status in (
      'active',
      'pending_review',
      'pending_funding',
      'pending_execution',
      'revoked',
      'exhausted',
      'expired'
    )
  ),
  add constraint video_improvement_authorizations_request_key_check check (
    char_length(request_idempotency_key) between 8 and 128
  ),
  add constraint video_improvement_authorizations_pending_reasons_check check (
    pending_reasons <@ array[
      'review_not_latest',
      'review_not_improve',
      'review_consumed',
      'insufficient_credits',
      'active_generation'
    ]::text[]
    and (
      (status in ('pending_review', 'pending_funding', 'pending_execution')
        and cardinality(pending_reasons) > 0)
      or
      (status not in ('pending_review', 'pending_funding', 'pending_execution')
        and cardinality(pending_reasons) = 0)
    )
  );

create unique index video_improvement_authorizations_request_uidx
  on public.video_improvement_authorizations (
    user_id,
    request_idempotency_key
  );

create index video_improvement_authorizations_resumable_idx
  on public.video_improvement_authorizations (
    user_id,
    valid_until,
    created_at desc
  )
  where status in (
    'active',
    'pending_review',
    'pending_funding',
    'pending_execution'
  );

create or replace function public.video_authorize_and_reserve_improvement(
  p_user_id uuid,
  p_idempotency_key text,
  p_source_artifact_id uuid,
  p_source_review_id uuid,
  p_valid_until timestamptz,
  p_total_regenerations smallint,
  p_rights_confirmed boolean,
  p_adult_confirmed boolean,
  p_terms_confirmed boolean,
  p_prohibited_content_confirmed boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account public.video_credit_accounts%rowtype;
  v_artifact public.video_artifacts%rowtype;
  v_review public.video_artifact_reviews%rowtype;
  v_source_job public.video_generation_jobs%rowtype;
  v_existing_job public.video_generation_jobs%rowtype;
  v_authorization public.video_improvement_authorizations%rowtype;
  v_job public.video_generation_jobs%rowtype;
  v_pending_reasons text[] := '{}'::text[];
  v_status text := 'active';
  v_required_credits constant bigint := 300;
begin
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;
  if p_valid_until < now() + interval '10 minutes'
    or p_valid_until > now() + interval '30 days' then
    raise exception 'invalid_authorization_expiry' using errcode = '22023';
  end if;
  if p_total_regenerations not between 1 and 24 then
    raise exception 'invalid_authorization_iterations' using errcode = '22023';
  end if;
  if not coalesce(p_rights_confirmed, false)
    or not coalesce(p_adult_confirmed, false)
    or not coalesce(p_terms_confirmed, false)
    or not coalesce(p_prohibited_content_confirmed, false) then
    raise exception 'authorization_confirmations_required'
      using errcode = '22023';
  end if;

  insert into public.video_credit_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select *
  into v_account
  from public.video_credit_accounts
  where user_id = p_user_id
  for update;

  select *
  into v_authorization
  from public.video_improvement_authorizations
  where user_id = p_user_id
    and request_idempotency_key = trim(p_idempotency_key)
  for update;

  if found then
    if v_authorization.root_artifact_id is distinct from p_source_artifact_id
      or v_authorization.initial_review_id is distinct from p_source_review_id
      or v_authorization.total_regeneration_limit
        is distinct from p_total_regenerations then
      raise exception 'authorization_idempotency_conflict'
        using errcode = 'P0001';
    end if;
    select *
    into v_existing_job
    from public.video_generation_jobs
    where user_id = p_user_id
      and authorization_id = v_authorization.id
      and idempotency_key = trim(p_idempotency_key);
    return jsonb_build_object(
      'authorization_id', v_authorization.id,
      'job_id', v_existing_job.id,
      'status', coalesce(v_existing_job.status, v_authorization.status),
      'pending_reasons', to_jsonb(v_authorization.pending_reasons),
      'idempotent_replay', true,
      'available_credits', v_account.available_credits,
      'reserved_credits', v_account.reserved_credits,
      'credit_debt', v_account.credit_debt,
      'authorization_remaining_credits',
        v_authorization.total_credit_limit
          - v_authorization.consumed_credits
          - v_authorization.reserved_credits,
      'authorization_remaining_regenerations',
        v_authorization.total_regeneration_limit
          - v_authorization.consumed_regenerations
    );
  end if;

  select *
  into v_artifact
  from public.video_artifacts
  where id = p_source_artifact_id
    and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_artifact_not_found' using errcode = 'P0002';
  end if;
  if v_artifact.rights_status = 'blocked'
    or v_artifact.privacy_status = 'blocked' then
    raise exception 'artifact_clearance_blocked' using errcode = 'P0001';
  end if;

  select *
  into v_review
  from public.video_artifact_reviews
  where id = p_source_review_id
    and artifact_id = p_source_artifact_id
    and user_id = p_user_id;
  if not found then
    raise exception 'improvement_review_not_found' using errcode = 'P0002';
  end if;

  select *
  into strict v_source_job
  from public.video_generation_jobs
  where id = v_artifact.job_id
    and user_id = p_user_id;

  if v_artifact.latest_review_id is distinct from p_source_review_id then
    v_pending_reasons := array_append(v_pending_reasons, 'review_not_latest');
  end if;
  if v_review.decision <> 'improve' then
    v_pending_reasons := array_append(v_pending_reasons, 'review_not_improve');
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and applied_review_id = p_source_review_id
  ) then
    v_pending_reasons := array_append(v_pending_reasons, 'review_consumed');
  end if;
  if v_account.available_credits < v_required_credits then
    v_pending_reasons := array_append(v_pending_reasons, 'insufficient_credits');
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and status in ('queued', 'in_progress')
  ) then
    v_pending_reasons := array_append(v_pending_reasons, 'active_generation');
  end if;

  if v_pending_reasons && array[
    'review_not_latest',
    'review_not_improve',
    'review_consumed'
  ]::text[] then
    v_status := 'pending_review';
  elsif 'insufficient_credits' = any(v_pending_reasons) then
    v_status := 'pending_funding';
  elsif 'active_generation' = any(v_pending_reasons) then
    v_status := 'pending_execution';
  end if;

  update public.video_improvement_authorizations
  set status = 'revoked',
      pending_reasons = '{}'::text[],
      revoked_at = now(),
      updated_at = now()
  where user_id = p_user_id
    and root_artifact_id = p_source_artifact_id
    and status in (
      'active',
      'pending_review',
      'pending_funding',
      'pending_execution'
    );

  insert into public.video_improvement_authorizations (
    user_id,
    request_idempotency_key,
    status,
    pending_reasons,
    last_reservation_attempt_at,
    valid_until,
    total_credit_limit,
    total_regeneration_limit,
    root_artifact_id,
    initial_review_id,
    model_key,
    duration_seconds,
    aspect_ratio,
    resolution,
    rights_confirmed,
    adult_confirmed,
    terms_confirmed,
    prohibited_content_confirmed
  ) values (
    p_user_id,
    trim(p_idempotency_key),
    v_status,
    v_pending_reasons,
    now(),
    p_valid_until,
    v_required_credits * p_total_regenerations,
    p_total_regenerations,
    v_artifact.id,
    v_review.id,
    v_source_job.model_key,
    v_source_job.duration_seconds,
    v_source_job.aspect_ratio,
    v_source_job.resolution,
    p_rights_confirmed,
    p_adult_confirmed,
    p_terms_confirmed,
    p_prohibited_content_confirmed
  )
  returning * into v_authorization;

  if cardinality(v_pending_reasons) > 0 then
    return jsonb_build_object(
      'authorization_id', v_authorization.id,
      'job_id', null,
      'status', v_authorization.status,
      'pending_reasons', to_jsonb(v_authorization.pending_reasons),
      'idempotent_replay', false,
      'available_credits', v_account.available_credits,
      'reserved_credits', v_account.reserved_credits,
      'credit_debt', v_account.credit_debt,
      'authorization_remaining_credits', v_authorization.total_credit_limit,
      'authorization_remaining_regenerations',
        v_authorization.total_regeneration_limit
    );
  end if;

  update public.video_credit_accounts
  set available_credits = available_credits - v_required_credits,
      reserved_credits = reserved_credits + v_required_credits,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_account;

  insert into public.video_generation_jobs (
    user_id,
    idempotency_key,
    model_key,
    inference_engine,
    model_revision,
    prompt,
    duration_seconds,
    aspect_ratio,
    resolution,
    quoted_credits,
    reserved_credits,
    parent_artifact_id,
    applied_review_id,
    authorization_id
  ) values (
    p_user_id,
    trim(p_idempotency_key),
    v_source_job.model_key,
    v_source_job.inference_engine,
    v_source_job.model_revision,
    trim(v_review.suggested_prompt),
    v_source_job.duration_seconds,
    v_source_job.aspect_ratio,
    v_source_job.resolution,
    v_required_credits,
    v_required_credits,
    v_artifact.id,
    v_review.id,
    v_authorization.id
  )
  returning * into v_job;

  update public.video_improvement_authorizations
  set reserved_credits = reserved_credits + v_required_credits,
      consumed_regenerations = consumed_regenerations + 1,
      updated_at = now()
  where id = v_authorization.id
  returning * into v_authorization;

  insert into public.video_credit_ledger (
    user_id,
    job_id,
    delta_available,
    delta_reserved,
    reason,
    reference
  ) values (
    p_user_id,
    v_job.id,
    -v_required_credits,
    v_required_credits,
    'generation_reserved',
    'video-job:' || v_job.id::text || ':reserve'
  );

  return jsonb_build_object(
    'authorization_id', v_authorization.id,
    'job_id', v_job.id,
    'status', v_job.status,
    'pending_reasons', '[]'::jsonb,
    'idempotent_replay', false,
    'available_credits', v_account.available_credits,
    'reserved_credits', v_account.reserved_credits,
    'credit_debt', v_account.credit_debt,
    'authorization_remaining_credits',
      v_authorization.total_credit_limit
        - v_authorization.consumed_credits
        - v_authorization.reserved_credits,
    'authorization_remaining_regenerations',
      v_authorization.total_regeneration_limit
        - v_authorization.consumed_regenerations
  );
end;
$$;

create or replace function public.video_reserve_authorized_improvement(
  p_user_id uuid,
  p_authorization_id uuid,
  p_source_artifact_id uuid,
  p_source_review_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account public.video_credit_accounts%rowtype;
  v_authorization public.video_improvement_authorizations%rowtype;
  v_artifact public.video_artifacts%rowtype;
  v_review public.video_artifact_reviews%rowtype;
  v_source_job public.video_generation_jobs%rowtype;
  v_existing_job public.video_generation_jobs%rowtype;
  v_job public.video_generation_jobs%rowtype;
  v_in_lineage boolean := false;
  v_pending_reasons text[] := '{}'::text[];
  v_status text := 'active';
  v_required_credits constant bigint := 300;
begin
  if char_length(trim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;

  select *
  into v_authorization
  from public.video_improvement_authorizations
  where id = p_authorization_id
    and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_authorization_not_found' using errcode = 'P0002';
  end if;

  insert into public.video_credit_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;
  select *
  into v_account
  from public.video_credit_accounts
  where user_id = p_user_id
  for update;

  select *
  into v_existing_job
  from public.video_generation_jobs
  where user_id = p_user_id
    and idempotency_key = trim(p_idempotency_key);
  if found then
    if v_existing_job.authorization_id is distinct from p_authorization_id then
      raise exception 'authorization_idempotency_conflict'
        using errcode = 'P0001';
    end if;
    return jsonb_build_object(
      'authorization_id', v_authorization.id,
      'job_id', v_existing_job.id,
      'status', v_existing_job.status,
      'pending_reasons', to_jsonb(v_authorization.pending_reasons),
      'idempotent_replay', true,
      'available_credits', v_account.available_credits,
      'reserved_credits', v_account.reserved_credits,
      'credit_debt', v_account.credit_debt,
      'authorization_remaining_credits',
        v_authorization.total_credit_limit
          - v_authorization.consumed_credits
          - v_authorization.reserved_credits,
      'authorization_remaining_regenerations',
        v_authorization.total_regeneration_limit
          - v_authorization.consumed_regenerations
    );
  end if;

  if v_authorization.status not in (
      'active',
      'pending_review',
      'pending_funding',
      'pending_execution'
    )
    or now() < v_authorization.valid_from
    or now() >= v_authorization.valid_until then
    raise exception 'video_authorization_inactive' using errcode = 'P0001';
  end if;
  if v_authorization.consumed_regenerations
      >= v_authorization.total_regeneration_limit
    or v_authorization.consumed_credits
      + v_authorization.reserved_credits
      + v_required_credits > v_authorization.total_credit_limit then
    raise exception 'video_authorization_exhausted' using errcode = 'P0001';
  end if;

  with recursive lineage(id) as (
    select v_authorization.root_artifact_id
    union all
    select child.id
    from public.video_artifacts child
    join lineage parent on child.parent_artifact_id = parent.id
    where child.user_id = p_user_id
  )
  select exists (
    select 1 from lineage where id = p_source_artifact_id
  ) into v_in_lineage;
  if not v_in_lineage then
    raise exception 'authorization_source_mismatch' using errcode = 'P0001';
  end if;

  select *
  into v_artifact
  from public.video_artifacts
  where id = p_source_artifact_id
    and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_artifact_not_found' using errcode = 'P0002';
  end if;
  if v_artifact.rights_status = 'blocked'
    or v_artifact.privacy_status = 'blocked' then
    raise exception 'artifact_clearance_blocked' using errcode = 'P0001';
  end if;

  select *
  into v_review
  from public.video_artifact_reviews
  where id = p_source_review_id
    and artifact_id = p_source_artifact_id
    and user_id = p_user_id;
  if not found then
    raise exception 'improvement_review_not_found' using errcode = 'P0002';
  end if;

  if v_artifact.latest_review_id is distinct from p_source_review_id then
    v_pending_reasons := array_append(v_pending_reasons, 'review_not_latest');
  end if;
  if v_review.decision <> 'improve' then
    v_pending_reasons := array_append(v_pending_reasons, 'review_not_improve');
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and applied_review_id = p_source_review_id
  ) then
    v_pending_reasons := array_append(v_pending_reasons, 'review_consumed');
  end if;
  if v_account.available_credits < v_required_credits then
    v_pending_reasons := array_append(v_pending_reasons, 'insufficient_credits');
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and status in ('queued', 'in_progress')
  ) then
    v_pending_reasons := array_append(v_pending_reasons, 'active_generation');
  end if;

  if v_pending_reasons && array[
    'review_not_latest',
    'review_not_improve',
    'review_consumed'
  ]::text[] then
    v_status := 'pending_review';
  elsif 'insufficient_credits' = any(v_pending_reasons) then
    v_status := 'pending_funding';
  elsif 'active_generation' = any(v_pending_reasons) then
    v_status := 'pending_execution';
  end if;

  if cardinality(v_pending_reasons) > 0 then
    update public.video_improvement_authorizations
    set status = v_status,
        pending_reasons = v_pending_reasons,
        last_reservation_attempt_at = now(),
        updated_at = now()
    where id = v_authorization.id
    returning * into v_authorization;
    return jsonb_build_object(
      'authorization_id', v_authorization.id,
      'job_id', null,
      'status', v_authorization.status,
      'pending_reasons', to_jsonb(v_authorization.pending_reasons),
      'idempotent_replay', false,
      'available_credits', v_account.available_credits,
      'reserved_credits', v_account.reserved_credits,
      'credit_debt', v_account.credit_debt,
      'authorization_remaining_credits',
        v_authorization.total_credit_limit
          - v_authorization.consumed_credits
          - v_authorization.reserved_credits,
      'authorization_remaining_regenerations',
        v_authorization.total_regeneration_limit
          - v_authorization.consumed_regenerations
    );
  end if;

  select *
  into strict v_source_job
  from public.video_generation_jobs
  where id = v_artifact.job_id
    and user_id = p_user_id;

  update public.video_credit_accounts
  set available_credits = available_credits - v_required_credits,
      reserved_credits = reserved_credits + v_required_credits,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_account;

  insert into public.video_generation_jobs (
    user_id,
    idempotency_key,
    model_key,
    inference_engine,
    model_revision,
    prompt,
    duration_seconds,
    aspect_ratio,
    resolution,
    quoted_credits,
    reserved_credits,
    parent_artifact_id,
    applied_review_id,
    authorization_id
  ) values (
    p_user_id,
    trim(p_idempotency_key),
    v_source_job.model_key,
    v_source_job.inference_engine,
    v_source_job.model_revision,
    trim(v_review.suggested_prompt),
    v_source_job.duration_seconds,
    v_source_job.aspect_ratio,
    v_source_job.resolution,
    v_required_credits,
    v_required_credits,
    v_artifact.id,
    v_review.id,
    v_authorization.id
  )
  returning * into v_job;

  update public.video_improvement_authorizations
  set status = 'active',
      pending_reasons = '{}'::text[],
      reserved_credits = reserved_credits + v_required_credits,
      consumed_regenerations = consumed_regenerations + 1,
      last_reservation_attempt_at = now(),
      updated_at = now()
  where id = v_authorization.id
  returning * into v_authorization;

  insert into public.video_credit_ledger (
    user_id,
    job_id,
    delta_available,
    delta_reserved,
    reason,
    reference
  ) values (
    p_user_id,
    v_job.id,
    -v_required_credits,
    v_required_credits,
    'generation_reserved',
    'video-job:' || v_job.id::text || ':reserve'
  );

  return jsonb_build_object(
    'authorization_id', v_authorization.id,
    'job_id', v_job.id,
    'status', v_job.status,
    'pending_reasons', '[]'::jsonb,
    'idempotent_replay', false,
    'available_credits', v_account.available_credits,
    'reserved_credits', v_account.reserved_credits,
    'credit_debt', v_account.credit_debt,
    'authorization_remaining_credits',
      v_authorization.total_credit_limit
        - v_authorization.consumed_credits
        - v_authorization.reserved_credits,
    'authorization_remaining_regenerations',
      v_authorization.total_regeneration_limit
        - v_authorization.consumed_regenerations
  );
end;
$$;

create or replace function public.video_settle_improvement_authorization()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.authorization_id is null
    or old.status in ('succeeded', 'failed', 'cancelled')
    or new.status not in ('succeeded', 'failed', 'cancelled') then
    return new;
  end if;

  update public.video_improvement_authorizations
  set reserved_credits = greatest(0, reserved_credits - old.reserved_credits),
      consumed_credits = consumed_credits + new.charged_credits,
      status = case
        when consumed_regenerations >= total_regeneration_limit
          or consumed_credits + new.charged_credits >= total_credit_limit
          then 'exhausted'
        else 'active'
      end,
      pending_reasons = '{}'::text[],
      updated_at = now()
  where id = new.authorization_id;
  return new;
end;
$$;

revoke all on function public.video_authorize_and_reserve_improvement(
  uuid,
  text,
  uuid,
  uuid,
  timestamptz,
  smallint,
  boolean,
  boolean,
  boolean,
  boolean
) from public, anon, authenticated;
revoke all on function public.video_reserve_authorized_improvement(
  uuid,
  uuid,
  uuid,
  uuid,
  text
) from public, anon, authenticated;
revoke all on function public.video_settle_improvement_authorization()
  from public, anon, authenticated;
grant execute on function public.video_authorize_and_reserve_improvement(
  uuid,
  text,
  uuid,
  uuid,
  timestamptz,
  smallint,
  boolean,
  boolean,
  boolean,
  boolean
) to service_role;
grant execute on function public.video_reserve_authorized_improvement(
  uuid,
  uuid,
  uuid,
  uuid,
  text
) to service_role;
grant execute on function public.video_settle_improvement_authorization()
  to service_role;
