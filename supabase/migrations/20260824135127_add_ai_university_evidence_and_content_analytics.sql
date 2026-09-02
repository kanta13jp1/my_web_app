-- Issue #4738: preserve optional, attributed course-selection evidence.
-- Existing rows deliberately remain NULL; this migration does not infer or
-- manufacture learner/outcome/assessment evidence.
alter table public.ai_university_content
  add column if not exists target_audience text
    check (target_audience is null or length(btrim(target_audience)) between 1 and 500),
  add column if not exists observable_learning_outcome text
    check (
      observable_learning_outcome is null
      or length(btrim(observable_learning_outcome)) between 1 and 1000
    ),
  add column if not exists assessment_verification_method text
    check (
      assessment_verification_method is null
      or length(btrim(assessment_verification_method)) between 1 and 1000
    ),
  add column if not exists evidence_source_url text
    check (
      evidence_source_url is null
      or (
        length(evidence_source_url) between 8 and 2048
        and evidence_source_url ~ '^https://'
      )
    ),
  add column if not exists evidence_verified_at timestamptz;

comment on column public.ai_university_content.target_audience is
  'Evidence-backed intended learner; NULL means not yet evidenced.';
comment on column public.ai_university_content.observable_learning_outcome is
  'Observable learner outcome; NULL means not yet evidenced.';
comment on column public.ai_university_content.assessment_verification_method is
  'How the learning outcome is assessed or verified; NULL means not yet evidenced.';
comment on column public.ai_university_content.evidence_source_url is
  'Official or primary source supporting the course-selection evidence.';
comment on column public.ai_university_content.evidence_verified_at is
  'Timestamp at which the attributed evidence was last verified.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ai_university_content'::regclass
      and conname = 'ai_university_course_evidence_complete'
  ) then
    alter table public.ai_university_content
      add constraint ai_university_course_evidence_complete check (
        num_nonnulls(
          target_audience,
          observable_learning_outcome,
          assessment_verification_method,
          evidence_source_url,
          evidence_verified_at
        ) = 0
        or (
          num_nonnulls(
            target_audience,
            observable_learning_outcome,
            assessment_verification_method,
            evidence_source_url,
            evidence_verified_at
          ) = 5
          and length(btrim(target_audience)) between 1 and 500
          and length(btrim(observable_learning_outcome)) between 1 and 1000
          and length(btrim(assessment_verification_method)) between 1 and 1000
          and length(evidence_source_url) between 8 and 2048
          and evidence_source_url ~ '^https://'
        )
      );
  end if;
end
$$;

-- Anonymous aggregate operational events only. There is intentionally no
-- user/session/IP/URL/error/content column and clients receive no SELECT grant.
create table if not exists public.ai_university_content_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null check (
    event_name in (
      'content_fetch_failed',
      'fallback_shown',
      'retry_requested',
      'retry_succeeded',
      'retry_failed'
    )
  ),
  surface text not null default 'ai_university_content'
    check (surface = 'ai_university_content'),
  occurred_at timestamptz not null default now()
);

comment on table public.ai_university_content_events is
  'Privacy-minimal anonymous AI University content reliability counters.';

create index if not exists ai_university_content_events_occurred_at_idx
  on public.ai_university_content_events (occurred_at desc);
create index if not exists ai_university_content_events_event_time_idx
  on public.ai_university_content_events (event_name, occurred_at desc);

alter table public.ai_university_content_events enable row level security;

revoke all on table public.ai_university_content_events
  from public, anon, authenticated;
grant insert (event_name, surface)
  on table public.ai_university_content_events to anon, authenticated;

-- Keep the migration safely repeatable in an isolated pre-production proof.
-- Supabase applies each migration transactionally, so replacement is atomic.
drop policy if exists "anonymous clients insert allowlisted content events"
  on public.ai_university_content_events;
create policy "anonymous clients insert allowlisted content events"
  on public.ai_university_content_events
  for insert
  to anon, authenticated
  with check (
    event_name in (
      'content_fetch_failed',
      'fallback_shown',
      'retry_requested',
      'retry_succeeded',
      'retry_failed'
    )
    and surface = 'ai_university_content'
  );
