-- Issue #2593: Stage-gate task approval workflow tables and RLS policies.
create table if not exists public.stage_gate_reviews (
  id uuid primary key default gen_random_uuid(),
  source_type text not null
    check (source_type in ('github_issue', 'notebooklm_intake', 'wbs_task')),
  source_ref text not null
    check (char_length(btrim(source_ref)) >= 1 and char_length(source_ref) <= 120),
  title text not null
    check (char_length(btrim(title)) >= 1 and char_length(title) <= 240),
  current_stage text not null
    check (current_stage in ('intake', 'design', 'implementation', 'verification', 'release')),
  target_stage text not null
    check (target_stage in ('intake', 'design', 'implementation', 'verification', 'release')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'changes_requested')),
  submitted_by uuid not null references auth.users(id) on delete cascade,
  decided_by uuid references auth.users(id) on delete set null,
  feedback text not null default ''
    check (char_length(feedback) <= 2000),
  validation_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_at timestamptz
);

create table if not exists public.stage_gate_approval_history (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.stage_gate_reviews(id) on delete cascade,
  from_stage text not null
    check (from_stage in ('intake', 'design', 'implementation', 'verification', 'release')),
  to_stage text not null
    check (to_stage in ('intake', 'design', 'implementation', 'verification', 'release')),
  decision text not null
    check (decision in ('submitted', 'approved', 'rejected', 'changes_requested')),
  actor_user_id uuid references auth.users(id) on delete set null,
  feedback text not null default ''
    check (char_length(feedback) <= 2000),
  created_at timestamptz not null default now()
);

create index if not exists stage_gate_reviews_status_created_idx
  on public.stage_gate_reviews (status, created_at desc);

create index if not exists stage_gate_reviews_submitter_idx
  on public.stage_gate_reviews (submitted_by, created_at desc);

create index if not exists stage_gate_history_review_created_idx
  on public.stage_gate_approval_history (review_id, created_at desc);

alter table public.stage_gate_reviews enable row level security;
alter table public.stage_gate_approval_history enable row level security;

drop policy if exists "stage_gate_reviews_select_owner_or_admin"
  on public.stage_gate_reviews;
create policy "stage_gate_reviews_select_owner_or_admin"
  on public.stage_gate_reviews
  for select
  using (
    submitted_by = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  );

drop policy if exists "stage_gate_reviews_insert_owner"
  on public.stage_gate_reviews;
create policy "stage_gate_reviews_insert_owner"
  on public.stage_gate_reviews
  for insert
  with check (
    submitted_by = (select auth.uid())
    and status = 'pending'
  );

drop policy if exists "stage_gate_reviews_update_admin_only"
  on public.stage_gate_reviews;
create policy "stage_gate_reviews_update_admin_only"
  on public.stage_gate_reviews
  for update
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles up
      where up.user_id = (select auth.uid())
        and (up.is_admin = true or up.role = 'admin')
    )
  );

drop policy if exists "stage_gate_history_select_owner_or_admin"
  on public.stage_gate_approval_history;
create policy "stage_gate_history_select_owner_or_admin"
  on public.stage_gate_approval_history
  for select
  using (
    exists (
      select 1
      from public.stage_gate_reviews r
      where r.id = stage_gate_approval_history.review_id
        and (
          r.submitted_by = (select auth.uid())
          or exists (
            select 1
            from public.user_profiles up
            where up.user_id = (select auth.uid())
              and (up.is_admin = true or up.role = 'admin')
          )
        )
    )
  );

-- History entries are append-only via trusted Edge Functions (service_role).
-- Explicitly deny direct INSERT/UPDATE/DELETE from client roles.
revoke insert, update, delete on public.stage_gate_approval_history
  from anon, authenticated;

drop policy if exists "stage_gate_history_deny_client_insert"
  on public.stage_gate_approval_history;
create policy "stage_gate_history_deny_client_insert"
  on public.stage_gate_approval_history
  for insert
  to anon, authenticated
  with check (false);

drop policy if exists "stage_gate_history_deny_client_update"
  on public.stage_gate_approval_history;
create policy "stage_gate_history_deny_client_update"
  on public.stage_gate_approval_history
  for update
  to anon, authenticated
  using (false)
  with check (false);

drop policy if exists "stage_gate_history_deny_client_delete"
  on public.stage_gate_approval_history;
create policy "stage_gate_approval_history_deny_client_delete"
  on public.stage_gate_approval_history
  for delete
  to anon, authenticated
  using (false);
