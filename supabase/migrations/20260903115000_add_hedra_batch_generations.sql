-- Issue #1182: group Hedra video variations without exposing generation
-- history to Data API clients. The Edge Function remains the service-role
-- boundary established by 20260815124052_fail_closed_rls_issue_2773.sql.
alter table public.viral_ad_generations
  add column if not exists user_id uuid references auth.users(id)
    on delete set null,
  add column if not exists batch_generation_id text,
  add column if not exists batch_size integer not null default 1,
  add column if not exists batch_results jsonb not null default '[]'::jsonb;

alter table public.viral_ad_generations
  drop constraint if exists viral_ad_generations_batch_size_check;

alter table public.viral_ad_generations
  add constraint viral_ad_generations_batch_size_check
  check (batch_size between 1 and 8);

create unique index if not exists idx_viral_ad_generations_batch_generation_id
  on public.viral_ad_generations (user_id, batch_generation_id)
  where batch_generation_id is not null;

create index if not exists idx_viral_ad_generations_user_created_at
  on public.viral_ad_generations (user_id, created_at desc);

revoke all privileges on table public.viral_ad_generations
  from public, anon, authenticated;

grant all privileges on table public.viral_ad_generations to service_role;
