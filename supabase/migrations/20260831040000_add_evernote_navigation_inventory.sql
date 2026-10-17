-- Preserve Evernote saved searches and shortcuts as owner-scoped account data.
--
-- nocheck: time-relative
-- This migration updates only newly introduced navigation tables and migration
-- ledger state. The disposable PostgreSQL contract proves replay-safe behavior.
--
-- ENEX does not include these account-level objects. The user therefore records
-- one explicit inventory snapshot, this migration hashes every source object,
-- and no migrated note may enter a source-deletion state until that inventory
-- (including an explicit zero-item inventory) is verified.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists evernote_migration_private;

create table public.note_saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  query text not null,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_saved_searches_id_user_key unique (id, user_id),
  constraint note_saved_searches_name_check
    check (char_length(btrim(name)) between 1 and 200),
  constraint note_saved_searches_query_check
    check (char_length(btrim(query)) between 1 and 4096),
  constraint note_saved_searches_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_saved_searches_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and char_length(source_key) between 1 and 512
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    )
);

create unique index note_saved_searches_source_key_idx
  on public.note_saved_searches (user_id, source_system, source_key)
  where source_key is not null;
create index note_saved_searches_user_updated_idx
  on public.note_saved_searches (user_id, updated_at desc, id);

create table public.note_shortcuts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  position integer not null,
  target_type text not null,
  target_note_id bigint,
  target_collection_id bigint,
  target_tag text,
  target_saved_search_id uuid,
  target_label text not null,
  source_target_key text,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_shortcuts_id_user_key unique (id, user_id),
  constraint note_shortcuts_position_check check (position >= 1),
  constraint note_shortcuts_user_position_key
    unique (user_id, position) deferrable initially immediate,
  constraint note_shortcuts_target_type_check
    check (target_type in ('note', 'notebook', 'stack', 'tag', 'saved_search')),
  constraint note_shortcuts_label_check
    check (char_length(btrim(target_label)) between 1 and 200),
  constraint note_shortcuts_tag_check
    check (
      target_tag is null
      or char_length(btrim(target_tag)) between 1 and 200
    ),
  constraint note_shortcuts_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_shortcuts_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and char_length(source_key) between 1 and 512
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    ),
  constraint note_shortcuts_note_owner_fkey
    foreign key (target_note_id, user_id)
    references public.notes (id, user_id)
    on delete restrict,
  constraint note_shortcuts_collection_owner_fkey
    foreign key (target_collection_id, user_id)
    references public.note_collections (id, user_id)
    on delete restrict,
  constraint note_shortcuts_saved_search_owner_fkey
    foreign key (target_saved_search_id, user_id)
    references public.note_saved_searches (id, user_id)
    on delete restrict,
  constraint note_shortcuts_target_shape_check
    check (
      (
        target_type = 'note'
        and target_collection_id is null
        and target_tag is null
        and target_saved_search_id is null
        and (target_note_id is not null or source_system = 'evernote')
      )
      or (
        target_type in ('notebook', 'stack')
        and target_note_id is null
        and target_tag is null
        and target_saved_search_id is null
        and (target_collection_id is not null or source_system = 'evernote')
      )
      or (
        target_type = 'tag'
        and target_note_id is null
        and target_collection_id is null
        and target_saved_search_id is null
        and target_tag is not null
      )
      or (
        target_type = 'saved_search'
        and target_note_id is null
        and target_collection_id is null
        and target_tag is null
        and (
          target_saved_search_id is not null
          or source_system = 'evernote'
        )
      )
    )
);

create unique index note_shortcuts_source_key_idx
  on public.note_shortcuts (user_id, source_system, source_key)
  where source_key is not null;
create index note_shortcuts_user_target_idx
  on public.note_shortcuts (user_id, target_type, position);

create table public.evernote_navigation_migrations (
  user_id uuid primary key references auth.users (id) on delete cascade,
  status text not null default 'pending',
  source_snapshot_sha256 text,
  source_saved_search_count bigint not null default 0,
  imported_saved_search_count bigint not null default 0,
  verified_saved_search_count bigint not null default 0,
  source_shortcut_count bigint not null default 0,
  imported_shortcut_count bigint not null default 0,
  verified_shortcut_count bigint not null default 0,
  source_metadata jsonb not null default '{}'::jsonb,
  verification_checks jsonb not null default '{}'::jsonb,
  imported_at timestamptz,
  verified_at timestamptz,
  source_deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evernote_navigation_migrations_status_check
    check (status in ('pending', 'imported', 'verified', 'source_deleted')),
  constraint evernote_navigation_migrations_hash_check
    check (
      source_snapshot_sha256 is null
      or source_snapshot_sha256 ~ '^[0-9a-f]{64}$'
    ),
  constraint evernote_navigation_migrations_counts_check
    check (
      source_saved_search_count >= 0
      and imported_saved_search_count between 0 and source_saved_search_count
      and verified_saved_search_count between 0 and imported_saved_search_count
      and source_shortcut_count >= 0
      and imported_shortcut_count between 0 and source_shortcut_count
      and verified_shortcut_count between 0 and imported_shortcut_count
    )
);

alter table public.note_saved_searches enable row level security;
alter table public.note_shortcuts enable row level security;
alter table public.evernote_navigation_migrations enable row level security;

create policy note_saved_searches_select_owner
  on public.note_saved_searches for select to authenticated
  using ((select auth.uid()) = user_id);
create policy note_saved_searches_insert_owner
  on public.note_saved_searches for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy note_saved_searches_update_owner
  on public.note_saved_searches for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy note_saved_searches_delete_owner
  on public.note_saved_searches for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy note_shortcuts_select_owner
  on public.note_shortcuts for select to authenticated
  using ((select auth.uid()) = user_id);
create policy note_shortcuts_insert_owner
  on public.note_shortcuts for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy note_shortcuts_update_owner
  on public.note_shortcuts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy note_shortcuts_delete_owner
  on public.note_shortcuts for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy evernote_navigation_migrations_select_owner
  on public.evernote_navigation_migrations for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_saved_searches
  from public, anon, authenticated, service_role;
revoke all on table public.note_shortcuts
  from public, anon, authenticated, service_role;
revoke all on table public.evernote_navigation_migrations
  from public, anon, authenticated, service_role;

grant select, insert, update, delete on table public.note_saved_searches
  to authenticated;
grant select, insert, update, delete on table public.note_shortcuts
  to authenticated;
grant select on table public.evernote_navigation_migrations
  to authenticated;
grant all on table public.note_saved_searches to service_role;
grant all on table public.note_shortcuts to service_role;
grant all on table public.evernote_navigation_migrations to service_role;

create or replace function
  evernote_migration_private.validate_note_shortcut_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_collection_type text;
begin
  if v_actor is not null and new.user_id <> v_actor then
    raise exception using
      errcode = '42501',
      message = 'A shortcut must belong to the authenticated user.';
  end if;

  if new.target_note_id is not null and not exists (
    select 1 from public.notes
    where id = new.target_note_id and user_id = new.user_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'The shortcut note target is not owned by this user.';
  end if;

  if new.target_saved_search_id is not null and not exists (
    select 1 from public.note_saved_searches
    where id = new.target_saved_search_id and user_id = new.user_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'The shortcut saved-search target is not owned by this user.';
  end if;

  if new.target_collection_id is not null then
    select collection_type
    into v_collection_type
    from public.note_collections
    where id = new.target_collection_id and user_id = new.user_id;

    if v_collection_type is null or v_collection_type <> new.target_type then
      raise exception using
        errcode = '23514',
        message = 'The shortcut collection target type does not match.';
    end if;
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.validate_note_shortcut_target()
  from public, anon, authenticated, service_role;

create trigger validate_note_shortcut_target
  before insert or update of
    user_id,
    target_type,
    target_note_id,
    target_collection_id,
    target_saved_search_id
  on public.note_shortcuts
  for each row
  execute function
    evernote_migration_private.validate_note_shortcut_target();

create or replace function
  evernote_migration_private.protect_evernote_navigation_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_deleted boolean;
begin
  if old.source_system <> 'evernote' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  select exists (
    select 1
    from public.evernote_navigation_migrations
    where user_id = old.user_id
      and status = 'source_deleted'
  )
  into v_source_deleted;

  if tg_op = 'DELETE' then
    if not v_source_deleted then
      raise exception using
        errcode = '23514',
        message =
          'Imported Evernote navigation evidence cannot be deleted before the source.';
    end if;
    return old;
  end if;

  if new.user_id is distinct from old.user_id
     or new.source_system is distinct from old.source_system
     or new.source_key is distinct from old.source_key
     or new.source_sha256 is distinct from old.source_sha256
     or new.source_metadata is distinct from old.source_metadata then
    raise exception using
      errcode = '23514',
      message = 'Imported Evernote navigation source evidence is immutable.';
  end if;

  if not v_source_deleted and tg_table_name = 'note_saved_searches' then
    if new.name is distinct from old.name
       or new.query is distinct from old.query then
      raise exception using
        errcode = '23514',
        message = 'Imported Evernote saved-search evidence is immutable.';
    end if;
  elsif not v_source_deleted and tg_table_name = 'note_shortcuts' then
    if new.position is distinct from old.position
       or new.target_type is distinct from old.target_type
       or new.target_tag is distinct from old.target_tag
       or new.target_label is distinct from old.target_label
       or new.source_target_key is distinct from old.source_target_key then
      raise exception using
        errcode = '23514',
        message = 'Imported Evernote shortcut evidence is immutable.';
    end if;
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.protect_evernote_navigation_source()
  from public, anon, authenticated, service_role;

create trigger protect_evernote_saved_search_source
  before update or delete on public.note_saved_searches
  for each row
  execute function
    evernote_migration_private.protect_evernote_navigation_source();

create trigger protect_evernote_shortcut_source
  before update or delete on public.note_shortcuts
  for each row
  execute function
    evernote_migration_private.protect_evernote_navigation_source();

create or replace function public.evernote_commit_navigation_inventory(
  p_saved_searches jsonb,
  p_shortcuts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_snapshot jsonb;
  v_snapshot_sha256 text;
  v_saved_search_count bigint;
  v_shortcut_count bigint;
  v_existing public.evernote_navigation_migrations%rowtype;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_saved_searches is null
     or jsonb_typeof(p_saved_searches) <> 'array'
     or p_shortcuts is null
     or jsonb_typeof(p_shortcuts) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'Saved searches and shortcuts must be JSON arrays.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_saved_searches) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or char_length(btrim(coalesce(item.value->>'source_key', '')))
        not between 1 and 512
      or char_length(btrim(coalesce(item.value->>'name', '')))
        not between 1 and 200
      or char_length(btrim(coalesce(item.value->>'query', '')))
        not between 1 and 4096
  ) or (
    select count(*) <> count(distinct item.value->>'source_key')
    from jsonb_array_elements(p_saved_searches) as item(value)
  ) then
    raise exception using
      errcode = '22023',
      message = 'The Evernote saved-search inventory is invalid.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_shortcuts) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or char_length(btrim(coalesce(item.value->>'source_key', '')))
        not between 1 and 512
      or coalesce(item.value->>'position', '') !~ '^[1-9][0-9]*$'
      or coalesce(item.value->>'target_type', '') not in
        ('note', 'notebook', 'stack', 'tag', 'saved_search')
      or char_length(btrim(coalesce(item.value->>'label', '')))
        not between 1 and 200
      or (
        item.value->>'target_type' = 'tag'
        and char_length(btrim(coalesce(item.value->>'target_tag', '')))
          not between 1 and 200
      )
  ) or (
    select count(*) <> count(distinct item.value->>'source_key')
    from jsonb_array_elements(p_shortcuts) as item(value)
  ) or (
    select count(*) <> count(distinct (item.value->>'position')::integer)
    from jsonb_array_elements(p_shortcuts) as item(value)
  ) then
    raise exception using
      errcode = '22023',
      message = 'The Evernote shortcut inventory is invalid.';
  end if;

  v_snapshot := jsonb_build_object(
    'saved_searches', p_saved_searches,
    'shortcuts', p_shortcuts
  );
  v_snapshot_sha256 := encode(
    extensions.digest(
      convert_to(v_snapshot::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
  v_saved_search_count := jsonb_array_length(p_saved_searches);
  v_shortcut_count := jsonb_array_length(p_shortcuts);

  select *
  into v_existing
  from public.evernote_navigation_migrations
  where user_id = v_user_id
  for update;

  if found
     and v_existing.source_snapshot_sha256 is not null
     and v_existing.source_snapshot_sha256 <> v_snapshot_sha256 then
    raise exception using
      errcode = '23514',
      message =
        'The Evernote navigation snapshot is already fixed; create a reviewed correction migration.';
  end if;

  if found
     and v_existing.status in ('verified', 'source_deleted') then
    return jsonb_build_object(
      'status', v_existing.status,
      'source_snapshot_sha256', v_existing.source_snapshot_sha256,
      'saved_search_count', v_existing.source_saved_search_count,
      'shortcut_count', v_existing.source_shortcut_count,
      'reused', true
    );
  end if;

  insert into public.note_saved_searches (
    user_id,
    name,
    query,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select
    v_user_id,
    btrim(item.value->>'name'),
    btrim(item.value->>'query'),
    'evernote',
    btrim(item.value->>'source_key'),
    encode(
      extensions.digest(
        convert_to(item.value::text, 'UTF8'),
        'sha256'
      ),
      'hex'
    ),
    item.value
  from jsonb_array_elements(p_saved_searches) as item(value)
  on conflict (user_id, source_system, source_key)
  where source_key is not null
  do update set
    name = excluded.name,
    query = excluded.query,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata,
    updated_at = clock_timestamp();

  insert into public.note_shortcuts (
    user_id,
    position,
    target_type,
    target_note_id,
    target_collection_id,
    target_tag,
    target_saved_search_id,
    target_label,
    source_target_key,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select
    v_user_id,
    (item.value->>'position')::integer,
    item.value->>'target_type',
    case
      when item.value->>'target_type' = 'note'
        and coalesce(item.value->>'target_note_id', '') ~ '^[0-9]+$'
      then (item.value->>'target_note_id')::bigint
    end,
    case
      when item.value->>'target_type' in ('notebook', 'stack')
        and coalesce(item.value->>'target_collection_id', '') ~ '^[0-9]+$'
      then (item.value->>'target_collection_id')::bigint
    end,
    case
      when item.value->>'target_type' = 'tag'
      then btrim(item.value->>'target_tag')
    end,
    case
      when item.value->>'target_type' = 'saved_search'
      then (
        select search.id
        from public.note_saved_searches as search
        where search.user_id = v_user_id
          and search.source_system = 'evernote'
          and search.source_key = item.value->>'target_source_key'
      )
    end,
    btrim(item.value->>'label'),
    nullif(btrim(coalesce(item.value->>'target_source_key', '')), ''),
    'evernote',
    btrim(item.value->>'source_key'),
    encode(
      extensions.digest(
        convert_to(item.value::text, 'UTF8'),
        'sha256'
      ),
      'hex'
    ),
    item.value
  from jsonb_array_elements(p_shortcuts) as item(value)
  on conflict (user_id, source_system, source_key)
  where source_key is not null
  do update set
    position = excluded.position,
    target_type = excluded.target_type,
    target_note_id = excluded.target_note_id,
    target_collection_id = excluded.target_collection_id,
    target_tag = excluded.target_tag,
    target_saved_search_id = excluded.target_saved_search_id,
    target_label = excluded.target_label,
    source_target_key = excluded.source_target_key,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata,
    updated_at = clock_timestamp();

  insert into public.evernote_navigation_migrations (
    user_id,
    status,
    source_snapshot_sha256,
    source_saved_search_count,
    imported_saved_search_count,
    source_shortcut_count,
    imported_shortcut_count,
    source_metadata,
    imported_at,
    updated_at
  )
  values (
    v_user_id,
    'imported',
    v_snapshot_sha256,
    v_saved_search_count,
    v_saved_search_count,
    v_shortcut_count,
    v_shortcut_count,
    v_snapshot,
    clock_timestamp(),
    clock_timestamp()
  )
  on conflict (user_id) do update set
    status = 'imported',
    source_snapshot_sha256 = excluded.source_snapshot_sha256,
    source_saved_search_count = excluded.source_saved_search_count,
    imported_saved_search_count = excluded.imported_saved_search_count,
    source_shortcut_count = excluded.source_shortcut_count,
    imported_shortcut_count = excluded.imported_shortcut_count,
    source_metadata = excluded.source_metadata,
    imported_at = excluded.imported_at,
    updated_at = excluded.updated_at;

  return jsonb_build_object(
    'status', 'imported',
    'source_snapshot_sha256', v_snapshot_sha256,
    'saved_search_count', v_saved_search_count,
    'shortcut_count', v_shortcut_count,
    'reused', false
  );
end
$$;

create or replace function public.evernote_verify_navigation_inventory(
  p_verification_checks jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_state public.evernote_navigation_migrations%rowtype;
  v_saved_search_count bigint;
  v_shortcut_count bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_verification_checks is null
     or jsonb_typeof(p_verification_checks) <> 'object'
     or not (
       coalesce((p_verification_checks->>'saved_search_count')::boolean, false)
       and coalesce((p_verification_checks->>'saved_search_queries')::boolean, false)
       and coalesce((p_verification_checks->>'shortcut_count')::boolean, false)
       and coalesce((p_verification_checks->>'shortcut_order')::boolean, false)
       and coalesce((p_verification_checks->>'shortcut_targets')::boolean, false)
     ) then
    raise exception using
      errcode = '23514',
      message = 'Every navigation verification check must be true.';
  end if;

  select *
  into v_state
  from public.evernote_navigation_migrations
  where user_id = v_user_id
  for update;

  if not found or v_state.status not in ('imported', 'verified') then
    raise exception using
      errcode = '23514',
      message = 'Import the Evernote navigation inventory before verifying it.';
  end if;

  select count(*)
  into v_saved_search_count
  from public.note_saved_searches
  where user_id = v_user_id and source_system = 'evernote';

  select count(*)
  into v_shortcut_count
  from public.note_shortcuts
  where user_id = v_user_id and source_system = 'evernote';

  if v_saved_search_count <> v_state.source_saved_search_count
     or v_shortcut_count <> v_state.source_shortcut_count
     or exists (
       select 1
       from public.note_shortcuts
       where user_id = v_user_id
         and source_system = 'evernote'
         and (
           (target_type = 'note' and target_note_id is null)
           or (
             target_type in ('notebook', 'stack')
             and target_collection_id is null
           )
           or (target_type = 'saved_search' and target_saved_search_id is null)
         )
     ) then
    raise exception using
      errcode = '23514',
      message = 'Navigation counts or shortcut targets are not fully resolved.';
  end if;

  update public.note_saved_searches
  set verified_at = clock_timestamp(), updated_at = clock_timestamp()
  where user_id = v_user_id and source_system = 'evernote';

  update public.note_shortcuts
  set verified_at = clock_timestamp(), updated_at = clock_timestamp()
  where user_id = v_user_id and source_system = 'evernote';

  update public.evernote_navigation_migrations
  set
    status = 'verified',
    verified_saved_search_count = v_saved_search_count,
    verified_shortcut_count = v_shortcut_count,
    verification_checks = p_verification_checks,
    verified_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where user_id = v_user_id;

  return jsonb_build_object(
    'status', 'verified',
    'source_snapshot_sha256', v_state.source_snapshot_sha256,
    'saved_search_count', v_saved_search_count,
    'shortcut_count', v_shortcut_count
  );
end
$$;

create or replace function public.note_shortcut_move(
  p_shortcut_id uuid,
  p_new_position integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_old_position integer;
  v_source_system text;
  v_source_deleted boolean;
  v_temporary_position integer;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  set constraints all deferred;
  if p_new_position < 1 then
    raise exception using
      errcode = '22023',
      message = 'Shortcut position must be positive.';
  end if;

  perform 1
  from public.note_shortcuts
  where user_id = v_user_id
  for update;

  select position, source_system
  into v_old_position, v_source_system
  from public.note_shortcuts
  where id = p_shortcut_id and user_id = v_user_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Shortcut was not found.';
  end if;

  if v_source_system = 'evernote' then
    select exists (
      select 1
      from public.evernote_navigation_migrations
      where user_id = v_user_id and status = 'source_deleted'
    )
    into v_source_deleted;
    if not v_source_deleted then
      raise exception using
        errcode = '23514',
        message = 'Imported shortcut order is fixed until source deletion.';
    end if;
  end if;

  p_new_position := least(
    p_new_position,
    (select count(*)::integer from public.note_shortcuts where user_id = v_user_id)
  );
  if p_new_position = v_old_position then
    return;
  end if;

  select coalesce(max(position), 0) + 1000000
  into v_temporary_position
  from public.note_shortcuts
  where user_id = v_user_id;

  update public.note_shortcuts
  set position = v_temporary_position
  where id = p_shortcut_id and user_id = v_user_id;

  if p_new_position < v_old_position then
    update public.note_shortcuts
    set position = position + 1
    where user_id = v_user_id
      and position >= p_new_position
      and position < v_old_position;
  else
    update public.note_shortcuts
    set position = position - 1
    where user_id = v_user_id
      and position > v_old_position
      and position <= p_new_position;
  end if;

  update public.note_shortcuts
  set position = p_new_position, updated_at = clock_timestamp()
  where id = p_shortcut_id and user_id = v_user_id;
end
$$;

create or replace function
  evernote_migration_private.enforce_navigation_before_source_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('source_deleting', 'source_deleted')
     and not exists (
       select 1
       from public.evernote_navigation_migrations
       where user_id = new.user_id
         and status in ('verified', 'source_deleted')
     ) then
    raise exception using
      errcode = '23514',
      message =
        'Evernote saved searches and shortcuts must be inventoried and verified before source deletion.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.enforce_navigation_before_source_deletion()
  from public, anon, authenticated, service_role;

create trigger enforce_evernote_navigation_before_source_deletion
  before insert or update of status
  on public.evernote_migration_items
  for each row
  execute function
    evernote_migration_private.enforce_navigation_before_source_deletion();

revoke all on function public.evernote_commit_navigation_inventory(jsonb, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.evernote_verify_navigation_inventory(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.note_shortcut_move(uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.evernote_commit_navigation_inventory(jsonb, jsonb)
  to authenticated;
grant execute on function public.evernote_verify_navigation_inventory(jsonb)
  to authenticated;
grant execute on function public.note_shortcut_move(uuid, integer)
  to authenticated;
