create table public.app_analytics (
  date date primary key default current_date,
  landing_views integer default 0,
  conversions integer default 0,
  share_count integer default 0,
  source_details jsonb default '{}'::jsonb,
  id uuid default gen_random_uuid(),
  user_id uuid,
  source text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

alter table public.app_analytics enable row level security;

create policy "Allow public access"
on public.app_analytics
for all
using (true)
with check (true);

grant all privileges on table public.app_analytics
to anon, authenticated, service_role;
