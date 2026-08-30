-- Machine-checkable, balance-only authorization envelopes for recurring
-- first-party video improvements. Creating an envelope and reserving its
-- first generation is atomic so an approval cannot be stranded unused.
-- nocheck: time-relative -- this migration updates only video_* tables; the
-- CI detector otherwise treats schema-qualified UPDATE public.video_* as an
-- UPDATE of the unrelated table named public.

create table public.video_improvement_authorizations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  environment text not null default 'production' check (
    environment = 'production'
  ),
  authorization_scope text not null default 'recurring' check (
    authorization_scope in ('one_time', 'recurring')
  ),
  status text not null default 'active' check (
    status in ('active', 'revoked', 'exhausted', 'expired')
  ),
  valid_from timestamptz not null default now(),
  valid_until timestamptz not null,
  per_run_credit_limit bigint not null default 300 check (
    per_run_credit_limit = 300
  ),
  total_credit_limit bigint not null check (total_credit_limit > 0),
  reserved_credits bigint not null default 0 check (reserved_credits >= 0),
  consumed_credits bigint not null default 0 check (consumed_credits >= 0),
  per_run_regeneration_limit smallint not null default 1 check (
    per_run_regeneration_limit = 1
  ),
  total_regeneration_limit smallint not null check (
    total_regeneration_limit between 1 and 24
  ),
  consumed_regenerations smallint not null default 0 check (
    consumed_regenerations between 0 and 24
  ),
  allow_credit_purchase boolean not null default false check (
    not allow_credit_purchase
  ),
  allowed_credit_pack text check (
    allowed_credit_pack is null or
    allowed_credit_pack in ('starter', 'creator', 'studio')
  ),
  max_spend_jpy_per_run integer not null default 0 check (
    max_spend_jpy_per_run = 0
  ),
  max_spend_jpy_total integer not null default 0 check (
    max_spend_jpy_total = 0
  ),
  consumed_spend_jpy integer not null default 0 check (
    consumed_spend_jpy = 0
  ),
  root_artifact_id uuid not null references public.video_artifacts(id),
  initial_review_id uuid not null references public.video_artifact_reviews(id),
  source_selection_rule text not null default 'latest_improve_descendant' check (
    source_selection_rule = 'latest_improve_descendant'
  ),
  model_key text not null check (model_key = 'studio-video-v1'),
  duration_seconds smallint not null check (duration_seconds = 5),
  aspect_ratio text not null check (aspect_ratio in ('16:9', '9:16')),
  resolution text not null check (resolution = '720p'),
  rights_confirmed boolean not null check (rights_confirmed),
  adult_confirmed boolean not null check (adult_confirmed),
  terms_confirmed boolean not null check (terms_confirmed),
  prohibited_content_confirmed boolean not null check (
    prohibited_content_confirmed
  ),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until > valid_from),
  check (
    total_credit_limit = per_run_credit_limit * total_regeneration_limit
  ),
  check (reserved_credits + consumed_credits <= total_credit_limit),
  check (consumed_regenerations <= total_regeneration_limit),
  check (
    (status = 'revoked' and revoked_at is not null) or
    (status <> 'revoked' and revoked_at is null)
  )
);

alter table public.video_generation_jobs
  add column authorization_id uuid references
    public.video_improvement_authorizations(id);

create index video_improvement_authorizations_user_created_idx
  on public.video_improvement_authorizations (user_id, created_at desc);
create index video_improvement_authorizations_active_idx
  on public.video_improvement_authorizations (
    user_id,
    valid_until,
    created_at desc
  )
  where status = 'active';
create index video_improvement_authorizations_root_idx
  on public.video_improvement_authorizations (root_artifact_id, created_at desc);
create index video_improvement_authorizations_initial_review_idx
  on public.video_improvement_authorizations (initial_review_id);
create index video_generation_jobs_authorization_idx
  on public.video_generation_jobs (authorization_id, created_at desc)
  where authorization_id is not null;
-- Historical manual retries can share applied_review_id. Preserve that immutable
-- lineage and enforce exactly-once consumption for authorization-backed jobs.
create unique index video_generation_jobs_applied_review_uidx
  on public.video_generation_jobs (user_id, applied_review_id)
  where applied_review_id is not null
    and authorization_id is not null;

alter table public.video_improvement_authorizations enable row level security;

create policy "video improvement authorizations select own"
  on public.video_improvement_authorizations
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.video_improvement_authorizations
  from anon, authenticated;
grant select on table public.video_improvement_authorizations
  to authenticated;
grant all on table public.video_improvement_authorizations
  to service_role;
grant select (authorization_id) on table public.video_generation_jobs
  to authenticated;

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
  into v_existing_job
  from public.video_generation_jobs
  where user_id = p_user_id
    and idempotency_key = trim(p_idempotency_key);

  if found then
    if v_existing_job.authorization_id is null then
      raise exception 'authorization_idempotency_conflict'
        using errcode = 'P0001';
    end if;
    select *
    into strict v_authorization
    from public.video_improvement_authorizations
    where id = v_existing_job.authorization_id
      and user_id = p_user_id;
    return jsonb_build_object(
      'authorization_id', v_authorization.id,
      'job_id', v_existing_job.id,
      'status', v_existing_job.status,
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

  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and status in ('queued', 'in_progress')
  ) then
    raise exception 'video_generation_already_active' using errcode = 'P0001';
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
  if v_artifact.latest_review_id is distinct from p_source_review_id then
    raise exception 'improvement_review_is_not_latest' using errcode = 'P0001';
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
  if not found or v_review.decision <> 'improve' then
    raise exception 'improvement_review_not_found' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and applied_review_id = p_source_review_id
  ) then
    raise exception 'improvement_review_already_consumed' using errcode = 'P0001';
  end if;

  select *
  into strict v_source_job
  from public.video_generation_jobs
  where id = v_artifact.job_id
    and user_id = p_user_id;

  if v_account.available_credits < v_required_credits then
    raise exception 'insufficient_video_credits' using errcode = 'P0001';
  end if;

  update public.video_improvement_authorizations
  set status = 'revoked',
      revoked_at = now(),
      updated_at = now()
  where user_id = p_user_id
    and root_artifact_id = p_source_artifact_id
    and status = 'active';

  insert into public.video_improvement_authorizations (
    user_id,
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

  if v_authorization.status <> 'active'
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
  if not found or v_artifact.latest_review_id is distinct from p_source_review_id then
    raise exception 'improvement_review_is_not_latest' using errcode = 'P0001';
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
  if not found or v_review.decision <> 'improve' then
    raise exception 'improvement_review_not_found' using errcode = 'P0002';
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and applied_review_id = p_source_review_id
  ) then
    raise exception 'improvement_review_already_consumed' using errcode = 'P0001';
  end if;
  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and status in ('queued', 'in_progress')
  ) then
    raise exception 'video_generation_already_active' using errcode = 'P0001';
  end if;
  if v_account.available_credits < v_required_credits then
    raise exception 'insufficient_video_credits' using errcode = 'P0001';
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
        else status
      end,
      updated_at = now()
  where id = new.authorization_id;
  return new;
end;
$$;

create trigger video_generation_jobs_settle_authorization
after update of status on public.video_generation_jobs
for each row execute function public.video_settle_improvement_authorization();

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
