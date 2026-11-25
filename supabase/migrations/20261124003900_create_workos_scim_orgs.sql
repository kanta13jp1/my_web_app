-- Batch 94 (#2683): WorkOS Admin Portal & Directory Sync (SCIM) B2B tenant management.
-- Extends existing `public.workos_user_link` (#1577) with org-scoped SCIM provisioning
-- state, Admin Portal intent tracking, idempotent webhook event audit log, and strict RLS.

create table if not exists public.workos_organizations (
  id uuid primary key default gen_random_uuid(),
  workos_org_id text not null unique
    check (char_length(btrim(workos_org_id)) between 1 and 120),
  organization_name text not null
    check (char_length(btrim(organization_name)) between 1 and 160),
  owner_user_id uuid not null default (select auth.uid()) references auth.users(id) on delete cascade,
  scim_enabled boolean not null default true,
  default_role text not null default 'member'
    check (default_role in ('admin', 'member', 'viewer')),
  admin_portal_last_intent text not null default 'dsync'
    check (
      admin_portal_last_intent in (
        'sso',
        'dsync',
        'audit_logs',
        'log_streams',
        'domain_verification',
        'certificate_renewal'
      )
    ),
  last_portal_generated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workos_organizations_owner
  on public.workos_organizations (owner_user_id, created_at desc);

create table if not exists public.workos_directory_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.workos_organizations(id) on delete cascade,
  workos_org_id text not null
    check (char_length(btrim(workos_org_id)) between 1 and 120),
  workos_directory_user_id text not null
    check (char_length(btrim(workos_directory_user_id)) between 1 and 160),
  workos_directory_id text not null default ''
    check (char_length(workos_directory_id) <= 160),
  supabase_user_id uuid references auth.users(id) on delete set null,
  email text not null
    check (char_length(btrim(email)) between 3 and 320),
  display_name text not null default ''
    check (char_length(display_name) <= 160),
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member', 'viewer')),
  provisioning_status text not null default 'active'
    check (provisioning_status in ('active', 'suspended', 'deprovisioned')),
  last_event_type text not null default 'dsync.user.created'
    check (last_event_type in ('dsync.user.created', 'dsync.user.updated', 'dsync.user.deleted')),
  last_synced_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (workos_org_id, workos_directory_user_id)
);

create index if not exists idx_workos_directory_memberships_org_status
  on public.workos_directory_memberships (organization_id, provisioning_status, last_synced_at desc);

create index if not exists idx_workos_directory_memberships_supabase_user
  on public.workos_directory_memberships (supabase_user_id)
  where supabase_user_id is not null;

create table if not exists public.workos_scim_sync_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.workos_organizations(id) on delete cascade,
  workos_org_id text not null
    check (char_length(btrim(workos_org_id)) between 1 and 120),
  workos_event_id text not null unique
    check (char_length(btrim(workos_event_id)) between 1 and 160),
  event_type text not null
    check (event_type in ('dsync.user.created', 'dsync.user.updated', 'dsync.user.deleted')),
  directory_user_id text not null default ''
    check (char_length(directory_user_id) <= 160),
  target_status text not null
    check (target_status in ('active', 'suspended', 'deprovisioned')),
  actor_user_id uuid references auth.users(id) on delete set null,
  payload_summary jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload_summary) = 'object' and length(payload_summary::text) <= 16384),
  processed_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workos_scim_sync_events_org_processed
  on public.workos_scim_sync_events (workos_org_id, processed_at desc);

alter table public.workos_organizations enable row level security;
alter table public.workos_directory_memberships enable row level security;
alter table public.workos_scim_sync_events enable row level security;

revoke all on table public.workos_organizations from public, anon;
grant select, insert, update on table public.workos_organizations to authenticated;
grant all on table public.workos_organizations to service_role;

revoke all on table public.workos_directory_memberships from public, anon;
grant select, insert, update on table public.workos_directory_memberships to authenticated;
grant all on table public.workos_directory_memberships to service_role;

revoke all on table public.workos_scim_sync_events from public, anon;
grant select on table public.workos_scim_sync_events to authenticated;
grant all on table public.workos_scim_sync_events to service_role;

create or replace function public._resolve_existing_workos_actor(p_candidate uuid)
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $fn$
  select case
    when p_candidate is null then null
    when exists (select 1 from auth.users as u where u.id = p_candidate) then p_candidate
    else null
  end;
$fn$;

revoke all on function public._resolve_existing_workos_actor(uuid)
  from public, anon, authenticated;

create or replace function public.is_workos_org_admin(p_workos_org_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select exists (
    select 1
    from public.user_profiles as up
    where up.user_id = (select auth.uid())
      and up.is_admin = true
  )
  or exists (
    select 1
    from public.workos_organizations as wo
    where wo.workos_org_id = p_workos_org_id
      and wo.owner_user_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.workos_directory_memberships as wdm
    where wdm.workos_org_id = p_workos_org_id
      and wdm.supabase_user_id = (select auth.uid())
      and wdm.provisioning_status = 'active'
      and wdm.role in ('owner', 'admin')
  );
$fn$;

revoke all on function public.is_workos_org_admin(text)
  from public, anon;
grant execute on function public.is_workos_org_admin(text)
  to authenticated, service_role;

create or replace function public.check_workos_org_access(
  p_workos_org_id text,
  p_required_role text default 'viewer'
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select exists (
    select 1
    from public.workos_organizations as wo
    where wo.workos_org_id = p_workos_org_id
      and (
        wo.owner_user_id = (select auth.uid())
        or exists (
          select 1
          from public.workos_directory_memberships as wdm
          where wdm.organization_id = wo.id
            and wdm.supabase_user_id = (select auth.uid())
            and wdm.provisioning_status = 'active'
            and (
              case wdm.role
                when 'owner' then 4
                when 'admin' then 3
                when 'member' then 2
                else 1
              end
            ) >= (
              case coalesce(p_required_role, 'viewer')
                when 'owner' then 4
                when 'admin' then 3
                when 'member' then 2
                else 1
              end
            )
        )
      )
  );
$fn$;

revoke all on function public.check_workos_org_access(text, text)
  from public, anon;
grant execute on function public.check_workos_org_access(text, text)
  to authenticated, service_role;

create or replace function public.guard_workos_scim_sync_events()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_temp
as $guard$
begin
  if new.actor_user_id is not null then
    new.actor_user_id := public._resolve_existing_workos_actor(new.actor_user_id);
  end if;
  new.processed_at := coalesce(new.processed_at, timezone('utc', now()));
  return new;
end;
$guard$;

revoke all on function public.guard_workos_scim_sync_events()
  from public, anon, authenticated;

drop trigger if exists guard_workos_scim_sync_events
  on public.workos_scim_sync_events;
create trigger guard_workos_scim_sync_events
  before insert or update on public.workos_scim_sync_events
  for each row
  execute function public.guard_workos_scim_sync_events();

drop policy if exists "workos_organizations_select_scoped"
  on public.workos_organizations;
create policy "workos_organizations_select_scoped"
  on public.workos_organizations
  for select
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or exists (
      select 1
      from public.workos_directory_memberships as wdm
      where wdm.organization_id = workos_organizations.id
        and wdm.supabase_user_id = (select auth.uid())
        and wdm.provisioning_status = 'active'
    )
  );

drop policy if exists "workos_organizations_insert_owner"
  on public.workos_organizations;
create policy "workos_organizations_insert_owner"
  on public.workos_organizations
  for insert
  to authenticated
  with check (
    owner_user_id is not null
    and owner_user_id = (select auth.uid())
  );

drop policy if exists "workos_organizations_update_admin"
  on public.workos_organizations;
create policy "workos_organizations_update_admin"
  on public.workos_organizations
  for update
  to authenticated
  using (
    owner_user_id = (select auth.uid())
    or public.is_workos_org_admin(workos_org_id)
  )
  with check (
    owner_user_id = (select auth.uid())
    or public.is_workos_org_admin(workos_org_id)
  );

drop policy if exists "workos_directory_memberships_select_scoped"
  on public.workos_directory_memberships;
create policy "workos_directory_memberships_select_scoped"
  on public.workos_directory_memberships
  for select
  to authenticated
  using (
    supabase_user_id = (select auth.uid())
    or public.is_workos_org_admin(workos_org_id)
  );

drop policy if exists "workos_directory_memberships_insert_admin"
  on public.workos_directory_memberships;
create policy "workos_directory_memberships_insert_admin"
  on public.workos_directory_memberships
  for insert
  to authenticated
  with check (public.is_workos_org_admin(workos_org_id));

drop policy if exists "workos_directory_memberships_update_admin"
  on public.workos_directory_memberships;
create policy "workos_directory_memberships_update_admin"
  on public.workos_directory_memberships
  for update
  to authenticated
  using (public.is_workos_org_admin(workos_org_id))
  with check (public.is_workos_org_admin(workos_org_id));

drop policy if exists "workos_scim_sync_events_select_admin"
  on public.workos_scim_sync_events;
create policy "workos_scim_sync_events_select_admin"
  on public.workos_scim_sync_events
  for select
  to authenticated
  using (public.is_workos_org_admin(workos_org_id));
