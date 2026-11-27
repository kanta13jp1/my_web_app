-- Migration for Issue #2686: Team Memory Shared Pattern Store & Scope Isolation Boundaries

create table if not exists public.team_memory_scopes (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('agent', 'org', 'project')),
  scope_id text not null check (scope_id ~ '^[a-zA-Z0-9_.:-]{2,120}$'),
  member_user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default timezone('utc', now()),
  unique (scope_type, scope_id, member_user_id)
);

create index if not exists idx_team_memory_scopes_member
  on public.team_memory_scopes (member_user_id, scope_type, scope_id);

create table if not exists public.team_memory_patterns (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('agent', 'org', 'project')),
  scope_id text not null check (scope_id ~ '^[a-zA-Z0-9_.:-]{2,120}$'),
  pattern_type text not null check (
    pattern_type in ('anti_pattern', 'success_rule', 'guardrail', 'workflow_pattern')
  ),
  abstract_rule text not null check (
    char_length(trim(abstract_rule)) between 10 and 1000
    and abstract_rule !~ '```'
    and abstract_rule !~ '(ghp_|github_pat_|sk-|xox[baprs]-|AIza|sb_secret_|Bearer\s+[A-Za-z0-9])'
  ),
  sanitized_summary text not null check (
    char_length(trim(sanitized_summary)) between 10 and 2000
    and sanitized_summary !~ '```'
    and sanitized_summary !~ '(ghp_|github_pat_|sk-|xox[baprs]-|AIza|sb_secret_|Bearer\s+[A-Za-z0-9])'
  ),
  redaction_count integer not null default 0 check (
    redaction_count >= 0 and redaction_count <= 10000
  ),
  is_sanitized boolean not null default false check (is_sanitized = true),
  source_session_hash text not null check (source_session_hash ~ '^[0-9a-f]{16,64}$'),
  created_by uuid not null references auth.users (id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_team_memory_patterns_scope_active
  on public.team_memory_patterns (scope_type, scope_id, is_active, created_at desc);

alter table public.team_memory_scopes enable row level security;
alter table public.team_memory_patterns enable row level security;

revoke all on table public.team_memory_scopes from public, anon, authenticated;
grant select on table public.team_memory_scopes to authenticated;
grant all on table public.team_memory_scopes to service_role;

revoke all on table public.team_memory_patterns from public, anon, authenticated;
grant select on table public.team_memory_patterns to authenticated;
grant all on table public.team_memory_patterns to service_role;

drop policy if exists "team_memory_scopes_select_own"
  on public.team_memory_scopes;
create policy "team_memory_scopes_select_own"
  on public.team_memory_scopes
  for select
  to authenticated
  using (member_user_id = (select auth.uid()));

drop policy if exists "team_memory_patterns_select_scoped"
  on public.team_memory_patterns;
create policy "team_memory_patterns_select_scoped"
  on public.team_memory_patterns
  for select
  to authenticated
  using (
    is_active = true
    and is_sanitized = true
    and exists (
      select 1
      from public.team_memory_scopes s
      where s.scope_type = team_memory_patterns.scope_type
        and s.scope_id = team_memory_patterns.scope_id
        and s.member_user_id = (select auth.uid())
    )
  );

create or replace function public.guard_team_memory_scopes()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
  v_is_service boolean;
begin
  if v_claims_raw is not null and length(trim(v_claims_raw)) > 0 then
    begin
      v_claims := v_claims_raw::jsonb;
    exception
      when others then
        v_claims := '{}'::jsonb;
    end;
  end if;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  if not v_is_service then
    raise exception 'team_memory_scopes mutations require service_role'
      using errcode = '42501';
  end if;

  if TG_OP = 'DELETE' then
    return old;
  end if;

  if TG_OP = 'INSERT' then
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    return new;
  end if;

  if new.id is distinct from old.id
    or new.scope_type is distinct from old.scope_type
    or new.scope_id is distinct from old.scope_id
    or new.member_user_id is distinct from old.member_user_id
    or new.created_at is distinct from old.created_at then
    raise exception 'Scope binding columns are immutable'
      using errcode = '42501';
  end if;

  return new;
end;
$guard$;

revoke all on function public.guard_team_memory_scopes() from public, anon, authenticated;

drop trigger if exists guard_team_memory_scopes
  on public.team_memory_scopes;
create trigger guard_team_memory_scopes
  before insert or update or delete on public.team_memory_scopes
  for each row
  execute function public.guard_team_memory_scopes();

create or replace function public.guard_team_memory_patterns()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
  v_is_service boolean;
  v_rpc_active boolean :=
    coalesce(current_setting('app.team_memory_rpc_active', true), '') = 'on';
begin
  if v_claims_raw is not null and length(trim(v_claims_raw)) > 0 then
    begin
      v_claims := v_claims_raw::jsonb;
    exception
      when others then
        v_claims := '{}'::jsonb;
    end;
  end if;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  if TG_OP = 'DELETE' then
    if not v_is_service then
      raise exception 'team_memory_patterns cannot be deleted directly'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if not v_is_service and not v_rpc_active then
    raise exception 'team_memory_patterns mutations must go through publish_team_memory_pattern'
      using errcode = '42501';
  end if;

  if TG_OP = 'INSERT' then
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if new.id is distinct from old.id
    or new.scope_type is distinct from old.scope_type
    or new.scope_id is distinct from old.scope_id
    or new.created_by is distinct from old.created_by
    or new.source_session_hash is distinct from old.source_session_hash
    or new.created_at is distinct from old.created_at then
    raise exception 'Scope and provenance columns are immutable on team_memory_patterns'
      using errcode = '42501';
  end if;

  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

revoke all on function public.guard_team_memory_patterns() from public, anon, authenticated;

drop trigger if exists guard_team_memory_patterns
  on public.team_memory_patterns;
create trigger guard_team_memory_patterns
  before insert or update or delete on public.team_memory_patterns
  for each row
  execute function public.guard_team_memory_patterns();

create or replace function public.publish_team_memory_pattern(
  p_scope_type text,
  p_scope_id text,
  p_pattern_type text,
  p_abstract_rule text,
  p_sanitized_summary text,
  p_redaction_count integer,
  p_source_session_hash text
)
returns public.team_memory_patterns
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_scope_type text := lower(trim(coalesce(p_scope_type, '')));
  v_scope_id text := trim(coalesce(p_scope_id, ''));
  v_pattern_type text := lower(trim(coalesce(p_pattern_type, '')));
  v_rule text := trim(coalesce(p_abstract_rule, ''));
  v_summary text := trim(coalesce(p_sanitized_summary, ''));
  v_hash text := lower(trim(coalesce(p_source_session_hash, '')));
  v_authorized boolean := false;
  v_created public.team_memory_patterns;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.team_memory_scopes s
    where s.scope_type = v_scope_type
      and s.scope_id = v_scope_id
      and s.member_user_id = v_uid
  )
  into v_authorized;

  if not v_authorized then
    raise exception 'Caller does not belong to target team_memory scope (%:%)', v_scope_type, v_scope_id
      using errcode = '42501';
  end if;

  perform set_config('app.team_memory_rpc_active', 'on', true);

  insert into public.team_memory_patterns (
    scope_type,
    scope_id,
    pattern_type,
    abstract_rule,
    sanitized_summary,
    redaction_count,
    is_sanitized,
    source_session_hash,
    created_by,
    is_active
  ) values (
    v_scope_type,
    v_scope_id,
    v_pattern_type,
    v_rule,
    v_summary,
    greatest(coalesce(p_redaction_count, 0), 0),
    true,
    v_hash,
    v_uid,
    true
  )
  returning * into v_created;

  perform set_config('app.team_memory_rpc_active', 'off', true);
  return v_created;
exception
  when others then
    perform set_config('app.team_memory_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.publish_team_memory_pattern(
  text, text, text, text, text, integer, text
) from public, anon;
grant execute on function public.publish_team_memory_pattern(
  text, text, text, text, text, integer, text
) to authenticated, service_role;

create or replace function public.query_team_memory_patterns(
  p_scope_type text,
  p_scope_id text,
  p_limit integer default 20
)
returns setof public.team_memory_patterns
language plpgsql
security definer
stable
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_scope_type text := lower(trim(coalesce(p_scope_type, '')));
  v_scope_id text := trim(coalesce(p_scope_id, ''));
  v_authorized boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.team_memory_scopes s
    where s.scope_type = v_scope_type
      and s.scope_id = v_scope_id
      and s.member_user_id = v_uid
  )
  into v_authorized;

  if not v_authorized then
    raise exception 'Cross-scope query blocked for %:%', v_scope_type, v_scope_id
      using errcode = '42501';
  end if;

  return query
  select p.*
  from public.team_memory_patterns p
  where p.scope_type = v_scope_type
    and p.scope_id = v_scope_id
    and p.is_active = true
    and p.is_sanitized = true
  order by p.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
end;
$fn$;

revoke all on function public.query_team_memory_patterns(
  text, text, integer
) from public, anon;
grant execute on function public.query_team_memory_patterns(
  text, text, integer
) to authenticated, service_role;

comment on table public.team_memory_scopes is
  'Explicit agent/org/project membership boundaries for cross-session Team Memory isolation (#2686).';
comment on table public.team_memory_patterns is
  'Abstracted and secret-sanitized anti-patterns and success rules scoped strictly by team_memory_scopes (#2686).';
