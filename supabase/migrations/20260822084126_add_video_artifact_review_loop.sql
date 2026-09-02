-- Preserve every successful first-party video as a durable creative artifact,
-- collect append-only owner reviews, and record which review informed the next
-- paid generation. Publication remains a separate, explicit approval step.

create table public.video_artifacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null unique
    references public.video_generation_jobs(id) on delete cascade,
  parent_artifact_id uuid references public.video_artifacts(id) on delete set null,
  title text not null check (char_length(title) between 1 and 140),
  kind text not null default 'video' check (kind = 'video'),
  storage_bucket text not null default 'video-generations'
    check (storage_bucket = 'video-generations'),
  storage_path text not null,
  content_type text not null default 'video/mp4'
    check (content_type = 'video/mp4'),
  file_size_bytes bigint check (
    file_size_bytes is null or file_size_bytes between 1 and 52428800
  ),
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  generator text not null default 'omocha_works_gpu'
    check (generator = 'omocha_works_gpu'),
  model_key text not null,
  model_revision text not null,
  prompt_snapshot text not null check (
    char_length(prompt_snapshot) between 1 and 1000
  ),
  duration_seconds smallint not null check (duration_seconds = 5),
  aspect_ratio text not null check (aspect_ratio in ('16:9', '9:16')),
  resolution text not null check (resolution = '720p'),
  lifecycle_stage text not null default 'captured' check (
    lifecycle_stage in (
      'captured',
      'rights_review',
      'productizing',
      'release_candidate',
      'blocked',
      'retired'
    )
  ),
  rights_status text not null default 'review_required' check (
    rights_status in ('review_required', 'allowed', 'blocked')
  ),
  privacy_status text not null default 'review_required' check (
    privacy_status in ('review_required', 'cleared', 'blocked')
  ),
  commerce_status text not null default 'sale_candidate' check (
    commerce_status in (
      'sale_candidate',
      'not_for_sale',
      'draft_product',
      'listed',
      'blocked'
    )
  ),
  intended_for_sale boolean not null default true,
  shop_product_id text references public.shop_products(id) on delete set null,
  iteration integer not null default 1 check (iteration between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.video_artifact_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  artifact_id uuid not null
    references public.video_artifacts(id) on delete cascade,
  iteration integer not null check (iteration between 1 and 1000),
  reviewer_type text not null default 'owner' check (reviewer_type = 'owner'),
  quality_score smallint not null check (quality_score between 1 and 5),
  prompt_alignment_score smallint not null check (
    prompt_alignment_score between 1 and 5
  ),
  motion_quality_score smallint not null check (
    motion_quality_score between 1 and 5
  ),
  commercial_value_score smallint not null check (
    commercial_value_score between 1 and 5
  ),
  decision text not null check (decision in ('keep', 'improve', 'reject')),
  strengths text not null default '' check (char_length(strengths) <= 1000),
  improvement_request text not null default '' check (
    char_length(improvement_request) <= 1500
  ),
  suggested_prompt text not null check (
    char_length(suggested_prompt) between 3 and 1000
  ),
  notes text not null default '' check (char_length(notes) <= 2000),
  created_at timestamptz not null default now(),
  unique (artifact_id, iteration)
);

alter table public.video_artifacts
  add column latest_review_id uuid
    references public.video_artifact_reviews(id) on delete set null;

alter table public.video_generation_jobs
  add column parent_artifact_id uuid
    references public.video_artifacts(id) on delete set null,
  add column applied_review_id uuid
    references public.video_artifact_reviews(id) on delete set null;

create table public.video_artifact_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  artifact_id uuid not null
    references public.video_artifacts(id) on delete cascade,
  review_id uuid references public.video_artifact_reviews(id) on delete set null,
  event_type text not null check (
    event_type in (
      'captured',
      'reviewed',
      'improvement_applied',
      'product_draft_linked',
      'retired'
    )
  ),
  metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(metadata) = 'object'
  ),
  created_at timestamptz not null default now()
);

create index video_artifacts_user_created_idx
  on public.video_artifacts (user_id, created_at desc);
create index video_artifacts_parent_idx
  on public.video_artifacts (parent_artifact_id)
  where parent_artifact_id is not null;
create index video_artifacts_shop_product_idx
  on public.video_artifacts (shop_product_id)
  where shop_product_id is not null;
create index video_artifact_reviews_user_created_idx
  on public.video_artifact_reviews (user_id, created_at desc);
create index video_artifact_reviews_artifact_created_idx
  on public.video_artifact_reviews (artifact_id, created_at desc);
create index video_generation_jobs_parent_artifact_idx
  on public.video_generation_jobs (parent_artifact_id)
  where parent_artifact_id is not null;
create index video_generation_jobs_applied_review_idx
  on public.video_generation_jobs (applied_review_id)
  where applied_review_id is not null;
create index video_artifact_events_user_created_idx
  on public.video_artifact_events (user_id, created_at desc);
create index video_artifact_events_artifact_created_idx
  on public.video_artifact_events (artifact_id, created_at desc);
create unique index video_artifact_single_capture_event_idx
  on public.video_artifact_events (artifact_id)
  where event_type = 'captured';

alter table public.video_artifacts enable row level security;
alter table public.video_artifact_reviews enable row level security;
alter table public.video_artifact_events enable row level security;

create policy "video artifacts select own"
  on public.video_artifacts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "video artifact reviews select own"
  on public.video_artifact_reviews
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "video artifact events select own"
  on public.video_artifact_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.video_artifacts from anon, authenticated;
revoke all on table public.video_artifact_reviews from anon, authenticated;
revoke all on table public.video_artifact_events from anon, authenticated;
grant select on table public.video_artifacts to authenticated;
grant select on table public.video_artifact_reviews to authenticated;
grant select on table public.video_artifact_events to authenticated;
grant select (parent_artifact_id, applied_review_id)
  on table public.video_generation_jobs to authenticated;
grant select, insert, update on table public.video_artifacts to service_role;
grant select, insert on table public.video_artifact_reviews to service_role;
grant select, insert on table public.video_artifact_events to service_role;
grant usage, select on sequence public.video_artifact_events_id_seq
  to service_role;

create or replace function public.video_artifact_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger video_artifacts_touch_updated_at
  before update on public.video_artifacts
  for each row execute function public.video_artifact_touch_updated_at();

create or replace function public.video_artifact_keep_original_immutable()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id
    or new.job_id is distinct from old.job_id
    or new.parent_artifact_id is distinct from old.parent_artifact_id
    or new.storage_bucket is distinct from old.storage_bucket
    or new.storage_path is distinct from old.storage_path
    or new.content_type is distinct from old.content_type
    or new.generator is distinct from old.generator
    or new.model_key is distinct from old.model_key
    or new.model_revision is distinct from old.model_revision
    or new.prompt_snapshot is distinct from old.prompt_snapshot
    or new.duration_seconds is distinct from old.duration_seconds
    or new.aspect_ratio is distinct from old.aspect_ratio
    or new.resolution is distinct from old.resolution
    or (old.file_size_bytes is not null
      and new.file_size_bytes is distinct from old.file_size_bytes)
    or (old.sha256 is not null and new.sha256 is distinct from old.sha256)
  then
    raise exception 'video_artifact_original_is_immutable'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger video_artifacts_keep_original_immutable
  before update on public.video_artifacts
  for each row execute function public.video_artifact_keep_original_immutable();

create or replace function public.video_capture_completed_artifact()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_artifact_id uuid;
begin
  if new.status <> 'succeeded' or new.output_storage_path is null then
    return new;
  end if;

  insert into public.video_artifacts (
    user_id,
    job_id,
    parent_artifact_id,
    title,
    storage_path,
    model_key,
    model_revision,
    prompt_snapshot,
    duration_seconds,
    aspect_ratio,
    resolution,
    iteration
  )
  values (
    new.user_id,
    new.id,
    new.parent_artifact_id,
    'AI動画 ' || to_char(
      coalesce(new.completed_at, now()) at time zone 'Asia/Tokyo',
      'YYYY-MM-DD HH24:MI'
    ),
    new.output_storage_path,
    new.model_key,
    new.model_revision,
    new.prompt,
    new.duration_seconds,
    new.aspect_ratio,
    new.resolution,
    coalesce((
      select parent.iteration + 1
      from public.video_artifacts as parent
      where parent.id = new.parent_artifact_id
        and parent.user_id = new.user_id
    ), 1)
  )
  on conflict (job_id) do nothing
  returning id into v_artifact_id;

  if v_artifact_id is not null then
    insert into public.video_artifact_events (
      user_id,
      artifact_id,
      event_type,
      metadata
    )
    values (
      new.user_id,
      v_artifact_id,
      'captured',
      jsonb_build_object(
        'job_id', new.id,
        'storage_bucket', 'video-generations'
      )
    );
  end if;
  return new;
end;
$$;

create trigger video_generation_capture_artifact
  after insert or update of status, output_storage_path
  on public.video_generation_jobs
  for each row execute function public.video_capture_completed_artifact();

-- Preserve successful videos generated before this migration.
insert into public.video_artifacts (
  user_id,
  job_id,
  title,
  storage_path,
  model_key,
  model_revision,
  prompt_snapshot,
  duration_seconds,
  aspect_ratio,
  resolution,
  created_at,
  updated_at
)
select
  job.user_id,
  job.id,
  'AI動画 ' || to_char(
    coalesce(job.completed_at, job.created_at) at time zone 'Asia/Tokyo',
    'YYYY-MM-DD HH24:MI'
  ),
  job.output_storage_path,
  job.model_key,
  job.model_revision,
  job.prompt,
  job.duration_seconds,
  job.aspect_ratio,
  job.resolution,
  coalesce(job.completed_at, job.created_at),
  coalesce(job.completed_at, job.updated_at)
from public.video_generation_jobs as job
where job.status = 'succeeded'
  and job.output_storage_path is not null
on conflict (job_id) do nothing;

insert into public.video_artifact_events (
  user_id,
  artifact_id,
  event_type,
  metadata,
  created_at
)
select
  artifact.user_id,
  artifact.id,
  'captured',
  jsonb_build_object(
    'job_id', artifact.job_id,
    'storage_bucket', artifact.storage_bucket,
    'backfilled', true
  ),
  artifact.created_at
from public.video_artifacts as artifact
on conflict (artifact_id) where event_type = 'captured' do nothing;

create or replace function public.video_record_artifact_review(
  p_user_id uuid,
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
  v_artifact public.video_artifacts%rowtype;
  v_review public.video_artifact_reviews%rowtype;
  v_iteration integer;
  v_lifecycle text;
  v_commerce text;
begin
  select * into v_artifact
  from public.video_artifacts
  where id = p_artifact_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_artifact_not_found' using errcode = 'P0001';
  end if;

  if p_quality_score not between 1 and 5
    or p_prompt_alignment_score not between 1 and 5
    or p_motion_quality_score not between 1 and 5
    or p_commercial_value_score not between 1 and 5
    or p_decision not in ('keep', 'improve', 'reject')
    or p_rights_status not in ('review_required', 'allowed', 'blocked')
    or p_privacy_status not in ('review_required', 'cleared', 'blocked')
    or char_length(trim(coalesce(p_suggested_prompt, ''))) not between 3 and 1000
    or char_length(coalesce(p_strengths, '')) > 1000
    or char_length(coalesce(p_improvement_request, '')) > 1500
    or char_length(coalesce(p_notes, '')) > 2000
  then
    raise exception 'invalid_video_artifact_review' using errcode = '22023';
  end if;

  select coalesce(max(iteration), 0) + 1 into v_iteration
  from public.video_artifact_reviews
  where artifact_id = p_artifact_id;

  insert into public.video_artifact_reviews (
    user_id,
    artifact_id,
    iteration,
    quality_score,
    prompt_alignment_score,
    motion_quality_score,
    commercial_value_score,
    decision,
    strengths,
    improvement_request,
    suggested_prompt,
    notes
  )
  values (
    p_user_id,
    p_artifact_id,
    v_iteration,
    p_quality_score,
    p_prompt_alignment_score,
    p_motion_quality_score,
    p_commercial_value_score,
    p_decision,
    trim(coalesce(p_strengths, '')),
    trim(coalesce(p_improvement_request, '')),
    trim(p_suggested_prompt),
    trim(coalesce(p_notes, ''))
  )
  returning * into v_review;

  v_lifecycle := case
    when p_decision = 'reject'
      or p_rights_status = 'blocked'
      or p_privacy_status = 'blocked' then 'blocked'
    when p_rights_status = 'allowed'
      and p_privacy_status = 'cleared' then 'productizing'
    else 'rights_review'
  end;
  v_commerce := case
    when v_lifecycle = 'blocked' then 'blocked'
    else 'sale_candidate'
  end;

  update public.video_artifacts
  set latest_review_id = v_review.id,
      lifecycle_stage = v_lifecycle,
      rights_status = p_rights_status,
      privacy_status = p_privacy_status,
      commerce_status = v_commerce
  where id = p_artifact_id
  returning * into v_artifact;

  insert into public.video_artifact_events (
    user_id,
    artifact_id,
    review_id,
    event_type,
    metadata
  )
  values (
    p_user_id,
    p_artifact_id,
    v_review.id,
    'reviewed',
    jsonb_build_object(
      'iteration', v_review.iteration,
      'decision', v_review.decision,
      'lifecycle_stage', v_artifact.lifecycle_stage
    )
  );

  return jsonb_build_object(
    'artifact', to_jsonb(v_artifact),
    'review', to_jsonb(v_review)
  );
end;
$$;

create or replace function public.video_link_generation_iteration(
  p_user_id uuid,
  p_job_id uuid,
  p_parent_artifact_id uuid,
  p_applied_review_id uuid
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_job public.video_generation_jobs%rowtype;
  v_review public.video_artifact_reviews%rowtype;
begin
  select * into v_job
  from public.video_generation_jobs
  where id = p_job_id and user_id = p_user_id
  for update;
  if not found or v_job.status not in ('queued', 'in_progress') then
    raise exception 'video_generation_not_linkable' using errcode = 'P0001';
  end if;

  select review.* into v_review
  from public.video_artifact_reviews as review
  join public.video_artifacts as artifact on artifact.id = review.artifact_id
  where review.id = p_applied_review_id
    and review.artifact_id = p_parent_artifact_id
    and review.user_id = p_user_id
    and artifact.user_id = p_user_id;
  if not found then
    raise exception 'video_improvement_review_not_found' using errcode = 'P0001';
  end if;

  if (v_job.parent_artifact_id is not null
      and v_job.parent_artifact_id <> p_parent_artifact_id)
    or (v_job.applied_review_id is not null
      and v_job.applied_review_id <> p_applied_review_id)
  then
    raise exception 'video_generation_iteration_conflict' using errcode = '23505';
  end if;

  update public.video_generation_jobs
  set parent_artifact_id = p_parent_artifact_id,
      applied_review_id = p_applied_review_id,
      updated_at = now()
  where id = p_job_id;

  insert into public.video_artifact_events (
    user_id,
    artifact_id,
    review_id,
    event_type,
    metadata
  )
  select
    p_user_id,
    p_parent_artifact_id,
    p_applied_review_id,
    'improvement_applied',
    jsonb_build_object('child_job_id', p_job_id)
  where not exists (
    select 1
    from public.video_artifact_events
    where artifact_id = p_parent_artifact_id
      and review_id = p_applied_review_id
      and event_type = 'improvement_applied'
      and metadata ->> 'child_job_id' = p_job_id::text
  );
  return true;
end;
$$;

revoke all on function public.video_artifact_touch_updated_at() from public;
revoke all on function public.video_artifact_keep_original_immutable() from public;
revoke all on function public.video_capture_completed_artifact() from public;
revoke all on function public.video_record_artifact_review(
  uuid, uuid, smallint, smallint, smallint, smallint, text, text, text,
  text, text, text, text
) from public, anon, authenticated;
revoke all on function public.video_link_generation_iteration(
  uuid, uuid, uuid, uuid
) from public, anon, authenticated;

grant execute on function public.video_record_artifact_review(
  uuid, uuid, smallint, smallint, smallint, smallint, text, text, text,
  text, text, text, text
) to service_role;
grant execute on function public.video_link_generation_iteration(
  uuid, uuid, uuid, uuid
) to service_role;

comment on table public.video_artifacts is
  'Immutable originals and commercialization readiness for first-party generated videos.';
comment on table public.video_artifact_reviews is
  'Append-only owner reviews and next-generation prompt improvements.';
comment on table public.video_artifact_events is
  'Append-only lifecycle evidence for capture, review, iteration, and productization.';
