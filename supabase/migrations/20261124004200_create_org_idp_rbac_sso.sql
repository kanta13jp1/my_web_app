-- Batch 99 (#2691): Organization / IdP group-based RBAC & SSO claims evaluation.
-- Extends `public.workos_organizations` and `public.workos_directory_memberships`
-- (#2683) with tenant-isolated IdP group-to-role mappings, SSO overage/audit
-- records, and safe custom JWT app_metadata claim evaluation helpers.

create table if not exists public.org_idp_group_mappings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  workos_org_id text not null
    check (char_length(btrim(workos_org_id)) between 1 and 120),
  foreign key (organization_id, workos_org_id)
    references public.workos_organizations(id, workos_org_id) on delete cascade,
  idp_provider text not null
    check (
      idp_provider in (
        'okta',
        'azure_ad',
        'google_workspace',
        'workos_sso',
        'generic_oidc',
        'generic_saml'
      )
    ),
  idp_group_id text not null
    check (char_length(btrim(idp_group_id)) between 1 and 200),
  idp_group_label text not null default ''
    check (char_length(idp_group_label) <= 160),
  mapped_role text not null
    check (mapped_role in ('owner', 'admin', 'member', 'viewer')),
  priority integer not null default 100
    check (priority between 1 and 1000),
  is_active boolean not null default true,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (workos_org_id, idp_provider, idp_group_id)
);

create index if not exists idx_org_idp_group_mappings_org_active
  on public.org_idp_group_mappings (organization_id, is_active, priority asc);

create table if not exists public.org_sso_sessions_audit (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  workos_org_id text not null
    check (char_length(btrim(workos_org_id)) between 1 and 120),
  foreign key (organization_id, workos_org_id)
    references public.workos_organizations(id, workos_org_id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  idp_provider text not null
    check (
      idp_provider in (
        'okta',
        'azure_ad',
        'google_workspace',
        'workos_sso',
        'generic_oidc',
        'generic_saml'
      )
    ),
  idp_subject text not null default ''
    check (char_length(idp_subject) <= 200),
  asserted_groups jsonb not null default '[]'::jsonb
    check (
      jsonb_typeof(asserted_groups) = 'array'
      and length(asserted_groups::text) <= 16384
    ),
  group_overage_detected boolean not null default false,
  resolved_role text not null
    check (resolved_role in ('owner', 'admin', 'member', 'viewer', 'none')),
  resolution_source text not null default 'idp_group_mapping'
    check (
      resolution_source in (
        'idp_group_mapping',
        'scim_directory',
        'org_owner',
        'overage_denied',
        'no_matching_group'
      )
    ),
  evaluated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_org_sso_sessions_audit_org_time
  on public.org_sso_sessions_audit (workos_org_id, evaluated_at desc);

create index if not exists idx_org_sso_sessions_audit_user_time
  on public.org_sso_sessions_audit (user_id, evaluated_at desc)
  where user_id is not null;

alter table public.org_idp_group_mappings enable row level security;
alter table public.org_sso_sessions_audit enable row level security;

revoke all on table public.org_idp_group_mappings from public, anon;
grant select, insert, update, delete on table public.org_idp_group_mappings to authenticated;
grant all on table public.org_idp_group_mappings to service_role;

revoke all on table public.org_sso_sessions_audit from public, anon, authenticated;
grant select on table public.org_sso_sessions_audit to authenticated;
grant all on table public.org_sso_sessions_audit to service_role;

create or replace function public._resolve_jwt_app_metadata()
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $fn$
declare
  raw_claims text;
  claims_json jsonb;
  app_meta jsonb;
begin
  raw_claims := nullif(current_setting('request.jwt.claims', true), '');
  if raw_claims is null then
    return '{}'::jsonb;
  end if;
  begin
    claims_json := raw_claims::jsonb;
  exception when others then
    return '{}'::jsonb;
  end;
  if jsonb_typeof(claims_json) <> 'object' then
    return '{}'::jsonb;
  end if;
  app_meta := claims_json -> 'app_metadata';
  if app_meta is null or jsonb_typeof(app_meta) <> 'object' then
    return '{}'::jsonb;
  end if;
  return app_meta;
end;
$fn$;

revoke all on function public._resolve_jwt_app_metadata()
  from public, anon;
grant execute on function public._resolve_jwt_app_metadata()
  to authenticated, service_role;

create or replace function public.resolve_jwt_org_idp_role(p_workos_org_id text)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  caller_uid uuid := (select auth.uid());
  app_meta jsonb := public._resolve_jwt_app_metadata();
  best_rank integer := 0;
  mapped_role_val text;
  jwt_role_val text;
  jwt_groups jsonb;
  overage_flag boolean := false;
  rank_candidate integer := 0;
begin
  if caller_uid is null or p_workos_org_id is null or btrim(p_workos_org_id) = '' then
    return 'none';
  end if;

  -- 1. Organization must exist; DB owner has highest authority.
  if not exists (
    select 1
    from public.workos_organizations as wo
    where wo.workos_org_id = p_workos_org_id
  ) then
    return 'none';
  end if;

  if exists (
    select 1
    from public.workos_organizations as wo
    where wo.workos_org_id = p_workos_org_id
      and wo.owner_user_id = caller_uid
  ) then
    return 'owner';
  end if;

  -- 2. SCIM directory membership status check (fail closed when suspended/deprovisioned).
  if exists (
    select 1
    from public.workos_directory_memberships as wdm
    where wdm.workos_org_id = p_workos_org_id
      and wdm.supabase_user_id = caller_uid
      and wdm.provisioning_status <> 'active'
  ) and not exists (
    select 1
    from public.workos_directory_memberships as wdm_active
    where wdm_active.workos_org_id = p_workos_org_id
      and wdm_active.supabase_user_id = caller_uid
      and wdm_active.provisioning_status = 'active'
  ) then
    return 'none';
  end if;

  select wdm.role
    into mapped_role_val
  from public.workos_directory_memberships as wdm
  where wdm.workos_org_id = p_workos_org_id
    and wdm.supabase_user_id = caller_uid
    and wdm.provisioning_status = 'active'
  order by case wdm.role
    when 'owner' then 4
    when 'admin' then 3
    when 'member' then 2
    when 'viewer' then 1
    else 0
  end desc
  limit 1;

  if mapped_role_val is not null then
    rank_candidate := case mapped_role_val
      when 'owner' then 4
      when 'admin' then 3
      when 'member' then 2
      when 'viewer' then 1
      else 0
    end;
    if rank_candidate > best_rank then
      best_rank := rank_candidate;
    end if;
  end if;

  -- 3. Trusted JWT app_metadata direct org role claim (written by Auth hook/admin).
  if jsonb_typeof(app_meta -> 'org_roles') = 'object' then
    jwt_role_val := app_meta -> 'org_roles' ->> p_workos_org_id;
    rank_candidate := case jwt_role_val
      when 'owner' then 4
      when 'admin' then 3
      when 'member' then 2
      when 'viewer' then 1
      else 0
    end;
    if rank_candidate > best_rank then
      best_rank := rank_candidate;
    end if;
  end if;

  -- 4. Trusted JWT app_metadata IdP group assertions unless Entra ID/Okta overage blocked claims.
  overage_flag := lower(
    coalesce(nullif(btrim(app_meta ->> 'idp_group_overage'), ''), 'false')
  ) in ('true', 't', '1');
  jwt_groups := app_meta -> 'idp_groups';
  if not overage_flag and jsonb_typeof(jwt_groups) = 'array' then
    select coalesce(
      max(
        case m.mapped_role
          when 'owner' then 4
          when 'admin' then 3
          when 'member' then 2
          when 'viewer' then 1
          else 0
        end
      ),
      0
    )
    into rank_candidate
    from public.org_idp_group_mappings as m
    where m.workos_org_id = p_workos_org_id
      and m.is_active = true
      and exists (
        select 1
        from jsonb_array_elements_text(jwt_groups) as grp(val)
        where lower(btrim(grp.val)) = lower(btrim(m.idp_group_id))
      );
    if rank_candidate > best_rank then
      best_rank := rank_candidate;
    end if;
  end if;

  return case best_rank
    when 4 then 'owner'
    when 3 then 'admin'
    when 2 then 'member'
    when 1 then 'viewer'
    else 'none'
  end;
end;
$fn$;

revoke all on function public.resolve_jwt_org_idp_role(text)
  from public, anon;
grant execute on function public.resolve_jwt_org_idp_role(text)
  to authenticated, service_role;

create or replace function public.check_org_idp_rbac(
  p_workos_org_id text,
  p_required_role text default 'viewer'
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select (
    case public.resolve_jwt_org_idp_role(p_workos_org_id)
      when 'owner' then 4
      when 'admin' then 3
      when 'member' then 2
      when 'viewer' then 1
      else 0
    end
  ) >= (
    case coalesce(p_required_role, 'viewer')
      when 'owner' then 4
      when 'admin' then 3
      when 'member' then 2
      when 'viewer' then 1
      else 5
    end
  );
$fn$;

revoke all on function public.check_org_idp_rbac(text, text)
  from public, anon;
grant execute on function public.check_org_idp_rbac(text, text)
  to authenticated, service_role;

create or replace function public.guard_org_idp_group_mappings()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $guard$
declare
  caller_uid uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' then
    if caller_uid is not null then
      new.created_by := caller_uid;
    elsif new.created_by is not null
      and not exists (select 1 from auth.users as u where u.id = new.created_by)
    then
      new.created_by := null;
    end if;
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
  end if;
  new.updated_at := timezone('utc', now());
  new.idp_provider := lower(btrim(new.idp_provider));
  new.idp_group_id := btrim(new.idp_group_id);
  new.workos_org_id := btrim(new.workos_org_id);
  return new;
end;
$guard$;

revoke all on function public.guard_org_idp_group_mappings()
  from public, anon, authenticated;

drop trigger if exists guard_org_idp_group_mappings
  on public.org_idp_group_mappings;
create trigger guard_org_idp_group_mappings
  before insert or update on public.org_idp_group_mappings
  for each row
  execute function public.guard_org_idp_group_mappings();

create or replace function public.guard_org_sso_sessions_audit()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $guard$
begin
  if new.user_id is not null
    and not exists (select 1 from auth.users as u where u.id = new.user_id)
  then
    new.user_id := null;
  end if;
  new.evaluated_at := coalesce(new.evaluated_at, timezone('utc', now()));
  return new;
end;
$guard$;

revoke all on function public.guard_org_sso_sessions_audit()
  from public, anon, authenticated;

drop trigger if exists guard_org_sso_sessions_audit
  on public.org_sso_sessions_audit;
create trigger guard_org_sso_sessions_audit
  before insert on public.org_sso_sessions_audit
  for each row
  execute function public.guard_org_sso_sessions_audit();

drop policy if exists "org_idp_group_mappings_select_scoped"
  on public.org_idp_group_mappings;
create policy "org_idp_group_mappings_select_scoped"
  on public.org_idp_group_mappings
  for select
  to authenticated
  using (
    public.is_workos_org_admin(workos_org_id)
    or exists (
      select 1
      from public.workos_directory_memberships as wdm
      where wdm.workos_org_id = org_idp_group_mappings.workos_org_id
        and wdm.supabase_user_id = (select auth.uid())
        and wdm.provisioning_status = 'active'
    )
  );

drop policy if exists "org_idp_group_mappings_insert_admin"
  on public.org_idp_group_mappings;
create policy "org_idp_group_mappings_insert_admin"
  on public.org_idp_group_mappings
  for insert
  to authenticated
  with check (
    public.is_workos_org_admin(workos_org_id)
    and created_by = (select auth.uid())
    and exists (
      select 1
      from public.workos_organizations as wo_org
      where wo_org.id = organization_id
        and wo_org.workos_org_id = org_idp_group_mappings.workos_org_id
    )
    and (
      mapped_role <> 'owner'
      or exists (
        select 1
        from public.workos_organizations as wo
        where wo.workos_org_id = org_idp_group_mappings.workos_org_id
          and wo.owner_user_id = (select auth.uid())
      )
    )
  );

drop policy if exists "org_idp_group_mappings_update_admin"
  on public.org_idp_group_mappings;
create policy "org_idp_group_mappings_update_admin"
  on public.org_idp_group_mappings
  for update
  to authenticated
  using (public.is_workos_org_admin(workos_org_id))
  with check (
    public.is_workos_org_admin(workos_org_id)
    and exists (
      select 1
      from public.workos_organizations as wo_org
      where wo_org.id = organization_id
        and wo_org.workos_org_id = org_idp_group_mappings.workos_org_id
    )
    and (
      mapped_role <> 'owner'
      or exists (
        select 1
        from public.workos_organizations as wo
        where wo.workos_org_id = org_idp_group_mappings.workos_org_id
          and wo.owner_user_id = (select auth.uid())
      )
    )
  );

drop policy if exists "org_idp_group_mappings_delete_admin"
  on public.org_idp_group_mappings;
create policy "org_idp_group_mappings_delete_admin"
  on public.org_idp_group_mappings
  for delete
  to authenticated
  using (public.is_workos_org_admin(workos_org_id));

drop policy if exists "org_sso_sessions_audit_select_scoped"
  on public.org_sso_sessions_audit;
create policy "org_sso_sessions_audit_select_scoped"
  on public.org_sso_sessions_audit
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_workos_org_admin(workos_org_id)
  );
