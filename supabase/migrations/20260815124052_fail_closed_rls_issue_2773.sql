-- Issue #2773: fail closed at the database boundary for tables that were
-- reachable from the Data API without row-level security.

-- This table existed in production without a matching migration. Capture the
-- production shape so a clean migration replay can apply the RLS hardening.
create table if not exists public.ai_benchmark_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  model_name text not null,
  provider text not null,
  vision_score integer not null,
  latency_ms integer not null,
  detail text,
  tested_at timestamptz default now()
);

create index if not exists idx_model_tested_at
  on public.ai_benchmark_results (model_name, tested_at desc);

create index if not exists idx_ai_benchmark_results_user_id
  on public.ai_benchmark_results (user_id);

alter table public.ai_benchmark_results enable row level security;
alter table public.referral_tracking enable row level security;
alter table public.competitor_feature_status enable row level security;
alter table public.ab_experiments enable row level security;
alter table public.ab_assignments enable row level security;
alter table public.viral_ad_generations enable row level security;

-- RLS does not protect TRUNCATE, REFERENCES, or TRIGGER privileges. Remove the
-- historical blanket grants first, then grant only operations backed by an
-- explicit policy. Service-role callers remain the trusted backend boundary.
revoke all privileges on table
  public.ai_benchmark_results,
  public.referral_tracking,
  public.competitor_feature_status,
  public.ab_experiments,
  public.ab_assignments,
  public.viral_ad_generations
from public, anon, authenticated;

grant all privileges on table
  public.ai_benchmark_results,
  public.referral_tracking,
  public.competitor_feature_status,
  public.ab_experiments,
  public.ab_assignments,
  public.viral_ad_generations
to service_role;

grant select on table public.ai_benchmark_results to authenticated;
grant select on table public.referral_tracking to authenticated;
grant select on table public.ab_experiments to authenticated;
grant select, insert, update, delete on table public.ab_assignments
  to authenticated;

drop policy if exists ai_benchmark_results_select_own
  on public.ai_benchmark_results;
create policy ai_benchmark_results_select_own
  on public.ai_benchmark_results
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists referral_tracking_select_participant
  on public.referral_tracking;
create policy referral_tracking_select_participant
  on public.referral_tracking
  for select
  to authenticated
  using (
    (select auth.uid())::text = referrer_user_id
    or (select auth.uid())::text = referred_user_id
  );

-- Experiment definitions are shared configuration, but only a request with a
-- real authenticated subject may read them.
drop policy if exists ab_experiments_authenticated_read
  on public.ab_experiments;
create policy ab_experiments_authenticated_read
  on public.ab_experiments
  for select
  to authenticated
  using ((select auth.uid()) is not null);

drop policy if exists ab_assignments_select_own
  on public.ab_assignments;
create policy ab_assignments_select_own
  on public.ab_assignments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists ab_assignments_insert_own
  on public.ab_assignments;
create policy ab_assignments_insert_own
  on public.ab_assignments
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists ab_assignments_update_own
  on public.ab_assignments;
create policy ab_assignments_update_own
  on public.ab_assignments
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists ab_assignments_delete_own
  on public.ab_assignments;
create policy ab_assignments_delete_own
  on public.ab_assignments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
