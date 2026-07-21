-- Issue #2476 [資産管理][第2弾D]: anomaly_detections storage.
-- This migration adds storage only; deterministic detection logic, AI
-- explanation generation, and UI wiring arrive in later 第2弾D tasks.
-- Amount semantics: expected/actual are JPY amounts computed by the app
-- layer; delta = actual - expected (writer supplies all three).

create table if not exists public.anomaly_detections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  detected_at timestamptz not null default now(),
  category text not null,
  expected numeric(20, 4) not null,
  actual numeric(20, 4) not null,
  delta numeric(20, 4) not null,
  severity text not null,
  ai_explanation text,
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint anomaly_detections_severity_valid
    check (severity in ('low', 'medium', 'high')),
  constraint anomaly_detections_category_not_blank
    check (length(btrim(category)) > 0)
);

create index if not exists anomaly_detections_user_detected_idx
  on public.anomaly_detections (user_id, detected_at desc);

alter table public.anomaly_detections enable row level security;

drop policy if exists anomaly_detections_select_own
  on public.anomaly_detections;
create policy anomaly_detections_select_own
on public.anomaly_detections
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists anomaly_detections_insert_own
  on public.anomaly_detections;
create policy anomaly_detections_insert_own
on public.anomaly_detections
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists anomaly_detections_update_own
  on public.anomaly_detections;
create policy anomaly_detections_update_own
on public.anomaly_detections
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists anomaly_detections_delete_own
  on public.anomaly_detections;
create policy anomaly_detections_delete_own
on public.anomaly_detections
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.set_anomaly_detections_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists anomaly_detections_updated_at
  on public.anomaly_detections;
create trigger anomaly_detections_updated_at
before update on public.anomaly_detections
for each row execute function public.set_anomaly_detections_updated_at();

comment on table public.anomaly_detections is
  'Per-user asset-management anomaly records (第2弾D #2476). Detection is deterministic in the app layer; ai_explanation holds optional AI-generated commentary only. dismissed_at marks user dismissal.';
