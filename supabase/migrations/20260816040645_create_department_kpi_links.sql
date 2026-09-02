-- Issue #2480: route each of the six department views to an allowlisted KPI
-- provider. kpi_query stores an ai-hub action identifier, never executable SQL.

begin;

create table if not exists public.department_kpi_links (
  id uuid primary key default gen_random_uuid(),
  department text not null unique,
  feature_module text,
  kpi_query text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint department_kpi_links_department_valid
    check (
      department in (
        'accounting',
        'hr',
        'marketing',
        'sales',
        'development',
        'legal'
      )
    ),
  constraint department_kpi_links_feature_module_not_blank
    check (feature_module is null or length(btrim(feature_module)) > 0),
  constraint department_kpi_links_kpi_query_allowlisted_shape
    check (
      kpi_query is null
      or kpi_query ~ '^ai_hub\.[a-z][a-z0-9_]*$'
    ),
  constraint department_kpi_links_target_pair
    check ((feature_module is null) = (kpi_query is null))
);

comment on table public.department_kpi_links is
  'Read-only routing from six department views to allowlisted KPI providers.';
comment on column public.department_kpi_links.kpi_query is
  'Allowlisted ai-hub action identifier. This value must never be executed as SQL.';

alter table public.department_kpi_links enable row level security;

-- RLS does not restrict TRUNCATE, REFERENCES, or TRIGGER. Remove inherited
-- table privileges, then grant only the read path required by signed-in views.
revoke all privileges on table public.department_kpi_links
from public, anon, authenticated;

grant all privileges on table public.department_kpi_links to service_role;
grant select on table public.department_kpi_links to authenticated;

drop policy if exists department_kpi_links_authenticated_read
  on public.department_kpi_links;
create policy department_kpi_links_authenticated_read
  on public.department_kpi_links
  for select
  to authenticated
  using ((select auth.uid()) is not null);

create or replace function public.set_department_kpi_links_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists department_kpi_links_updated_at
  on public.department_kpi_links;
create trigger department_kpi_links_updated_at
before update on public.department_kpi_links
for each row execute function public.set_department_kpi_links_updated_at();

insert into public.department_kpi_links (
  department,
  feature_module,
  kpi_query
) values
  (
    'accounting',
    'asset_management',
    'ai_hub.department_finance_summary'
  ),
  ('hr', null, null),
  ('marketing', null, null),
  ('sales', null, null),
  ('development', null, null),
  ('legal', null, null)
on conflict (department) do update set
  feature_module = excluded.feature_module,
  kpi_query = excluded.kpi_query,
  updated_at = now()
where public.department_kpi_links.feature_module
        is distinct from excluded.feature_module
   or public.department_kpi_links.kpi_query
        is distinct from excluded.kpi_query;

commit;
