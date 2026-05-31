-- Persist AI asset-management analysis so future runs can reference the
-- user's previous guidance and progress.

create table if not exists public.asset_management_ai_analysis_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_fingerprint text not null,
  report_base_date date,
  status text not null,
  source text not null,
  summary_text text not null,
  provider_route jsonb not null default '{}'::jsonb,
  provider_choice_reason text,
  input_payload jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint asset_management_ai_analysis_history_status_valid
    check (status in ('aiGenerated', 'fallback', 'disabled')),
  constraint asset_management_ai_analysis_history_provider_route_object
    check (jsonb_typeof(provider_route) = 'object'),
  constraint asset_management_ai_analysis_history_input_payload_object
    check (jsonb_typeof(input_payload) = 'object')
);

create index if not exists asset_management_ai_analysis_history_user_generated_idx
  on public.asset_management_ai_analysis_history (user_id, generated_at desc);

create index if not exists asset_management_ai_analysis_history_user_fingerprint_idx
  on public.asset_management_ai_analysis_history (user_id, request_fingerprint);

alter table public.asset_management_ai_analysis_history enable row level security;

drop policy if exists asset_management_ai_analysis_history_select_own
  on public.asset_management_ai_analysis_history;
create policy asset_management_ai_analysis_history_select_own
on public.asset_management_ai_analysis_history
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists asset_management_ai_analysis_history_insert_own
  on public.asset_management_ai_analysis_history;
create policy asset_management_ai_analysis_history_insert_own
on public.asset_management_ai_analysis_history
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists asset_management_ai_analysis_history_update_own
  on public.asset_management_ai_analysis_history;
create policy asset_management_ai_analysis_history_update_own
on public.asset_management_ai_analysis_history
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists asset_management_ai_analysis_history_delete_own
  on public.asset_management_ai_analysis_history;
create policy asset_management_ai_analysis_history_delete_own
on public.asset_management_ai_analysis_history
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.set_asset_management_ai_analysis_history_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists asset_management_ai_analysis_history_updated_at
  on public.asset_management_ai_analysis_history;
create trigger asset_management_ai_analysis_history_updated_at
before update on public.asset_management_ai_analysis_history
for each row execute function public.set_asset_management_ai_analysis_history_updated_at();

comment on table public.asset_management_ai_analysis_history is
  'AI asset-management assistant outputs persisted per user so future analyses can reference prior advice and progress.';
