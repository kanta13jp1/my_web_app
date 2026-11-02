-- The retired analytics dashboard must not be shown as Notion parity evidence.
-- Keep the legacy application route as a safe home redirect, but remove it from
-- both existing capability rows and rows created by the already-deployed seed
-- trigger. The trigger keeps this migration forward-only instead of rewriting
-- the historical control-plane migration.
-- nocheck: time-relative
-- This file only updates notion_migration_capabilities.site_routes. The guard
-- otherwise reads the schema qualifier in `update public...` as table `public`.

create or replace function public.notion_migration_strip_retired_site_routes()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.site_routes := array_remove(
    new.site_routes,
    '/app-analytics-dashboard'
  );
  return new;
end;
$$;

revoke execute on function
  public.notion_migration_strip_retired_site_routes()
  from public, anon, authenticated;

create trigger notion_migration_capabilities_strip_retired_site_routes
  before insert or update of site_routes
  on public.notion_migration_capabilities
  for each row execute function
    public.notion_migration_strip_retired_site_routes();

update public.notion_migration_capabilities
set site_routes = array_remove(site_routes, '/app-analytics-dashboard')
where '/app-analytics-dashboard' = any(site_routes);
