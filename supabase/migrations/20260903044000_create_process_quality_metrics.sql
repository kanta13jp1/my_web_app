-- Issue #2888: append-only process review density metrics.
create table if not exists public.process_quality_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_name text not null
    check (
      char_length(btrim(project_name)) >= 1
      and char_length(project_name) <= 120
    ),
  feature_name text not null default ''
    check (char_length(feature_name) <= 120),
  scope_unit text not null
    check (scope_unit in ('features', 'pages', 'test_cases', 'documents')),
  scope_size numeric(12, 2) not null
    check (scope_size > 0 and scope_size <= 1000000),
  review_minutes integer not null
    check (review_minutes > 0 and review_minutes <= 1000000),
  finding_count integer not null
    check (finding_count >= 0 and finding_count <= 1000000),
  minimum_review_density numeric(12, 4) not null default 5
    check (minimum_review_density >= 0),
  minimum_finding_density numeric(12, 4) not null default 0.5
    check (minimum_finding_density >= 0),
  review_density numeric(16, 4) generated always as (
    round(review_minutes::numeric / scope_size, 4)
  ) stored,
  finding_density numeric(16, 4) generated always as (
    round(finding_count::numeric / scope_size, 4)
  ) stored,
  needs_attention boolean generated always as (
    review_minutes::numeric / scope_size < minimum_review_density
    or finding_count::numeric / scope_size < minimum_finding_density
  ) stored,
  reviewed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.process_quality_metrics is
  'User-scoped, append-only review effort and finding density measurements.';
comment on column public.process_quality_metrics.needs_attention is
  'True when either density is below the thresholds recorded with the review.';

create index if not exists process_quality_metrics_user_reviewed_idx
  on public.process_quality_metrics (user_id, reviewed_at desc);

alter table public.process_quality_metrics enable row level security;

revoke all on table public.process_quality_metrics from public, anon, authenticated;
grant select, insert on table public.process_quality_metrics to authenticated;
grant all on table public.process_quality_metrics to service_role;

drop policy if exists "Users can read own process quality metrics"
  on public.process_quality_metrics;
create policy "Users can read own process quality metrics"
  on public.process_quality_metrics
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own process quality metrics"
  on public.process_quality_metrics;
create policy "Users can insert own process quality metrics"
  on public.process_quality_metrics
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);
