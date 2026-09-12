-- Preserve Evernote nested tags as owner-scoped first-class data.
--
-- nocheck: time-relative
-- ENEX retains tag names per note but not the account-level parent tree. The
-- user therefore supplies one separately reviewed inventory (including an
-- explicit zero-item inventory). Every tag, parent edge, and imported note/tag
-- assignment is hashed before any Evernote source-deletion state is allowed.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists evernote_migration_private;

create table public.note_tags (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  parent_id bigint,
  name text not null,
  normalized_name text generated always as (lower(btrim(name))) stored,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_tags_id_user_key unique (id, user_id),
  constraint note_tags_name_check
    check (char_length(btrim(name)) between 1 and 200),
  constraint note_tags_user_name_key unique (user_id, normalized_name),
  constraint note_tags_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_tags_parent_not_self_check
    check (parent_id is null or parent_id <> id),
  constraint note_tags_parent_owner_fkey
    foreign key (parent_id, user_id)
    references public.note_tags (id, user_id)
    on delete restrict,
  constraint note_tags_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and char_length(source_key) between 1 and 512
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    )
);

create unique index note_tags_source_key_idx
  on public.note_tags (user_id, source_system, source_key)
  where source_key is not null;
create index note_tags_user_parent_idx
  on public.note_tags (user_id, parent_id, normalized_name);

create table public.note_tag_assignments (
  user_id uuid not null references auth.users (id) on delete cascade,
  note_id bigint not null,
  tag_id bigint not null,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_id, note_id, tag_id),
  constraint note_tag_assignments_note_owner_fkey
    foreign key (note_id, user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint note_tag_assignments_tag_owner_fkey
    foreign key (tag_id, user_id)
    references public.note_tags (id, user_id)
    on delete cascade,
  constraint note_tag_assignments_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_tag_assignments_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and char_length(source_key) between 1 and 2048
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    )
);

create unique index note_tag_assignments_source_key_idx
  on public.note_tag_assignments (user_id, source_system, source_key)
  where source_key is not null;
create index note_tag_assignments_tag_idx
  on public.note_tag_assignments (user_id, tag_id, note_id);

create table public.evernote_tag_migrations (
  user_id uuid primary key references auth.users (id) on delete cascade,
  status text not null default 'pending',
  source_snapshot_sha256 text,
  source_tag_count bigint not null default 0,
  imported_tag_count bigint not null default 0,
  verified_tag_count bigint not null default 0,
  source_assignment_count bigint not null default 0,
  imported_assignment_count bigint not null default 0,
  verified_assignment_count bigint not null default 0,
  source_metadata jsonb not null default '{}'::jsonb,
  verification_checks jsonb not null default '{}'::jsonb,
  imported_at timestamptz,
  verified_at timestamptz,
  source_deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint evernote_tag_migrations_status_check
    check (status in ('pending', 'imported', 'verified', 'source_deleted')),
  constraint evernote_tag_migrations_hash_check
    check (
      source_snapshot_sha256 is null
      or source_snapshot_sha256 ~ '^[0-9a-f]{64}$'
    ),
  constraint evernote_tag_migrations_counts_check
    check (
      source_tag_count >= 0
      and imported_tag_count >= 0
      and verified_tag_count >= 0
      and source_assignment_count >= 0
      and imported_assignment_count >= 0
      and verified_assignment_count >= 0
    )
);

alter table public.note_tags enable row level security;
alter table public.note_tag_assignments enable row level security;
alter table public.evernote_tag_migrations enable row level security;

create policy note_tags_select_owner
  on public.note_tags for select to authenticated
  using ((select auth.uid()) = user_id);
create policy note_tags_insert_owner
  on public.note_tags for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy note_tags_update_owner
  on public.note_tags for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy note_tags_delete_owner
  on public.note_tags for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy note_tag_assignments_select_owner
  on public.note_tag_assignments for select to authenticated
  using ((select auth.uid()) = user_id);
create policy note_tag_assignments_insert_owner
  on public.note_tag_assignments for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy note_tag_assignments_delete_owner
  on public.note_tag_assignments for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy evernote_tag_migrations_select_owner
  on public.evernote_tag_migrations for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_tags
  from public, anon, authenticated, service_role;
revoke all on table public.note_tag_assignments
  from public, anon, authenticated, service_role;
revoke all on table public.evernote_tag_migrations
  from public, anon, authenticated, service_role;

grant select, delete on table public.note_tags to authenticated;
grant insert (user_id, parent_id, name)
  on table public.note_tags to authenticated;
grant update (parent_id, name, updated_at)
  on table public.note_tags to authenticated;
grant select, delete on table public.note_tag_assignments to authenticated;
grant insert (user_id, note_id, tag_id)
  on table public.note_tag_assignments to authenticated;
grant select on table public.evernote_tag_migrations to authenticated;
grant all on table public.note_tags to service_role;
grant all on table public.note_tag_assignments to service_role;
grant all on table public.evernote_tag_migrations to service_role;

revoke all on sequence public.note_tags_id_seq
  from public, anon, authenticated, service_role;
grant usage, select on sequence public.note_tags_id_seq to authenticated;
grant all on sequence public.note_tags_id_seq to service_role;

create or replace function
  evernote_migration_private.validate_note_tag_parent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is not null and new.user_id <> v_actor then
    raise exception using
      errcode = '42501',
      message = 'A tag must belong to the authenticated user.';
  end if;
  if new.parent_id is null then
    return new;
  end if;
  if not exists (
    select 1
    from public.note_tags
    where id = new.parent_id and user_id = new.user_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'The parent tag does not exist for this user.';
  end if;
  if exists (
    with recursive ancestors as (
      select id, parent_id
      from public.note_tags
      where id = new.parent_id and user_id = new.user_id
      union all
      select parent.id, parent.parent_id
      from public.note_tags as parent
      join ancestors on ancestors.parent_id = parent.id
      where parent.user_id = new.user_id
    )
    select 1 from ancestors where id = new.id
  ) then
    raise exception using
      errcode = '23514',
      message = 'A nested tag hierarchy cannot contain a cycle.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.validate_note_tag_parent()
  from public, anon, authenticated, service_role;

create trigger validate_note_tag_parent
  before insert or update of user_id, parent_id
  on public.note_tags
  for each row
  execute function evernote_migration_private.validate_note_tag_parent();

create or replace function
  evernote_migration_private.protect_evernote_tag_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inventory_fixed boolean;
  v_source_deleted boolean;
begin
  if old.source_system <> 'evernote' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  select
    exists (
      select 1 from public.evernote_tag_migrations
      where user_id = old.user_id
    ),
    exists (
      select 1 from public.evernote_tag_migrations
      where user_id = old.user_id and status = 'source_deleted'
    )
  into v_inventory_fixed, v_source_deleted;

  if tg_op = 'DELETE' then
    if v_inventory_fixed and not v_source_deleted then
      raise exception using
        errcode = '23514',
        message =
          'Imported Evernote tag evidence cannot be deleted before the source.';
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
      message = 'Imported Evernote tag source evidence is immutable.';
  end if;

  if v_inventory_fixed
     and not v_source_deleted
     and tg_table_name = 'note_tags'
     and (
       to_jsonb(new)->>'name' is distinct from to_jsonb(old)->>'name'
       or to_jsonb(new)->>'parent_id'
         is distinct from to_jsonb(old)->>'parent_id'
     ) then
    raise exception using
      errcode = '23514',
      message = 'Imported Evernote tag hierarchy is immutable.';
  end if;

  if v_inventory_fixed
     and not v_source_deleted
     and tg_table_name = 'note_tag_assignments'
     and (
       to_jsonb(new)->>'note_id'
         is distinct from to_jsonb(old)->>'note_id'
       or to_jsonb(new)->>'tag_id'
         is distinct from to_jsonb(old)->>'tag_id'
     ) then
    raise exception using
      errcode = '23514',
      message = 'Imported Evernote tag assignments are immutable.';
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.protect_evernote_tag_source()
  from public, anon, authenticated, service_role;

create trigger protect_evernote_tag_source
  before update or delete on public.note_tags
  for each row
  execute function evernote_migration_private.protect_evernote_tag_source();

create trigger protect_evernote_tag_assignment_source
  before update or delete on public.note_tag_assignments
  for each row
  execute function evernote_migration_private.protect_evernote_tag_source();

create or replace function public.evernote_commit_tag_inventory(
  p_tags jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_canonical_tags jsonb;
  v_snapshot jsonb;
  v_snapshot_sha256 text;
  v_source_tag_count bigint;
  v_source_assignment_count bigint;
  v_imported_tag_count bigint;
  v_imported_assignment_count bigint;
  v_existing public.evernote_tag_migrations%rowtype;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_tags is null or jsonb_typeof(p_tags) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'The Evernote tag inventory must be a JSON array.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_tags) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or char_length(btrim(coalesce(item.value->>'source_key', '')))
        not between 1 and 512
      or char_length(btrim(coalesce(item.value->>'name', '')))
        not between 1 and 200
      or (
        nullif(btrim(coalesce(item.value->>'parent_source_key', '')), '')
          is not null
        and not exists (
          select 1
          from jsonb_array_elements(p_tags) as parent(value)
          where btrim(parent.value->>'source_key') =
            btrim(item.value->>'parent_source_key')
        )
      )
      or btrim(item.value->>'source_key') =
        nullif(btrim(coalesce(item.value->>'parent_source_key', '')), '')
  ) or (
    select count(*) <> count(distinct btrim(item.value->>'source_key'))
    from jsonb_array_elements(p_tags) as item(value)
  ) or (
    select count(*) <> count(distinct lower(btrim(item.value->>'name')))
    from jsonb_array_elements(p_tags) as item(value)
  ) then
    raise exception using
      errcode = '22023',
      message = 'The Evernote tag inventory is invalid.';
  end if;

  select coalesce(
    jsonb_agg(item.value order by item.value->>'source_key'),
    '[]'::jsonb
  )
  into v_canonical_tags
  from jsonb_array_elements(p_tags) as item(value);

  v_snapshot := jsonb_build_object('tags', v_canonical_tags);
  v_snapshot_sha256 := encode(
    extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'),
    'hex'
  );
  v_source_tag_count := jsonb_array_length(p_tags);

  select *
  into v_existing
  from public.evernote_tag_migrations
  where user_id = v_user_id
  for update;

  if found
     and v_existing.source_snapshot_sha256 is not null
     and v_existing.source_snapshot_sha256 <> v_snapshot_sha256 then
    raise exception using
      errcode = '23514',
      message =
        'The Evernote tag snapshot is already fixed; create a reviewed correction migration.';
  end if;

  if found and v_existing.status in ('verified', 'source_deleted') then
    return jsonb_build_object(
      'status', v_existing.status,
      'source_snapshot_sha256', v_existing.source_snapshot_sha256,
      'tag_count', v_existing.source_tag_count,
      'assignment_count', v_existing.source_assignment_count,
      'reused', true
    );
  end if;

  insert into public.note_tags (
    user_id,
    parent_id,
    name,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select
    v_user_id,
    null,
    btrim(item.value->>'name'),
    'evernote',
    btrim(item.value->>'source_key'),
    encode(
      extensions.digest(convert_to(item.value::text, 'UTF8'), 'sha256'),
      'hex'
    ),
    item.value
  from jsonb_array_elements(v_canonical_tags) as item(value)
  on conflict (user_id, source_system, source_key)
  where source_key is not null
  do update set
    name = excluded.name,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata,
    updated_at = clock_timestamp();

  update public.note_tags as child
  set
    parent_id = parent.id,
    updated_at = clock_timestamp()
  from jsonb_array_elements(v_canonical_tags) as item(value)
  left join public.note_tags as parent
    on parent.user_id = v_user_id
    and parent.source_system = 'evernote'
    and parent.source_key =
      nullif(btrim(coalesce(item.value->>'parent_source_key', '')), '')
  where child.user_id = v_user_id
    and child.source_system = 'evernote'
    and child.source_key = btrim(item.value->>'source_key')
    and child.parent_id is distinct from parent.id;

  if exists (
    select 1
    from public.evernote_migration_items as migration_item
    join public.notes as note
      on note.id = migration_item.target_note_id
      and note.user_id = migration_item.user_id
    cross join lateral unnest(note.tags) as source_tag(name)
    where migration_item.user_id = v_user_id
      and not exists (
        select 1
        from public.note_tags as tag
        where tag.user_id = v_user_id
          and tag.source_system = 'evernote'
          and tag.normalized_name = lower(btrim(source_tag.name))
      )
  ) then
    raise exception using
      errcode = '23514',
      message =
        'An imported note tag is missing from the fixed hierarchy inventory.';
  end if;

  insert into public.note_tag_assignments (
    user_id,
    note_id,
    tag_id,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select distinct
    v_user_id,
    migration_item.target_note_id,
    tag.id,
    'evernote',
    migration_item.source_item_key || '::' || tag.source_key,
    encode(
      extensions.digest(
        convert_to(
          jsonb_build_object(
            'note_source_key', migration_item.source_item_key,
            'tag_source_key', tag.source_key
          )::text,
          'UTF8'
        ),
        'sha256'
      ),
      'hex'
    ),
    jsonb_build_object(
      'note_source_key', migration_item.source_item_key,
      'tag_source_key', tag.source_key,
      'tag_name', source_tag.name
    )
  from public.evernote_migration_items as migration_item
  join public.notes as note
    on note.id = migration_item.target_note_id
    and note.user_id = migration_item.user_id
  cross join lateral unnest(note.tags) as source_tag(name)
  join public.note_tags as tag
    on tag.user_id = v_user_id
    and tag.source_system = 'evernote'
    and tag.normalized_name = lower(btrim(source_tag.name))
  where migration_item.user_id = v_user_id
  on conflict (user_id, note_id, tag_id)
  do update set
    source_system = excluded.source_system,
    source_key = excluded.source_key,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata;

  select count(*)
  into v_imported_tag_count
  from public.note_tags
  where user_id = v_user_id and source_system = 'evernote';

  select count(*)
  into v_imported_assignment_count
  from public.note_tag_assignments
  where user_id = v_user_id and source_system = 'evernote';

  select count(*)
  into v_source_assignment_count
  from (
    select distinct migration_item.target_note_id, tag.id
    from public.evernote_migration_items as migration_item
    join public.notes as note
      on note.id = migration_item.target_note_id
      and note.user_id = migration_item.user_id
    cross join lateral unnest(note.tags) as source_tag(name)
    join public.note_tags as tag
      on tag.user_id = v_user_id
      and tag.source_system = 'evernote'
      and tag.normalized_name = lower(btrim(source_tag.name))
    where migration_item.user_id = v_user_id
  ) as expected_assignment;

  if v_imported_tag_count <> v_source_tag_count
     or v_imported_assignment_count <> v_source_assignment_count then
    raise exception using
      errcode = '23514',
      message = 'The Evernote tag hierarchy or assignments are incomplete.';
  end if;

  insert into public.evernote_tag_migrations (
    user_id,
    status,
    source_snapshot_sha256,
    source_tag_count,
    imported_tag_count,
    source_assignment_count,
    imported_assignment_count,
    source_metadata,
    imported_at,
    updated_at
  )
  values (
    v_user_id,
    'imported',
    v_snapshot_sha256,
    v_source_tag_count,
    v_imported_tag_count,
    v_source_assignment_count,
    v_imported_assignment_count,
    v_snapshot,
    clock_timestamp(),
    clock_timestamp()
  )
  on conflict (user_id) do update set
    status = excluded.status,
    source_snapshot_sha256 = excluded.source_snapshot_sha256,
    source_tag_count = excluded.source_tag_count,
    imported_tag_count = excluded.imported_tag_count,
    source_assignment_count = excluded.source_assignment_count,
    imported_assignment_count = excluded.imported_assignment_count,
    source_metadata = excluded.source_metadata,
    imported_at = excluded.imported_at,
    updated_at = excluded.updated_at;

  return jsonb_build_object(
    'status', 'imported',
    'source_snapshot_sha256', v_snapshot_sha256,
    'tag_count', v_imported_tag_count,
    'assignment_count', v_imported_assignment_count,
    'reused', false
  );
end
$$;

create or replace function public.evernote_verify_tag_inventory(
  p_verification_checks jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_state public.evernote_tag_migrations%rowtype;
  v_tag_count bigint;
  v_assignment_count bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_verification_checks is null
     or jsonb_typeof(p_verification_checks) <> 'object'
     or not (
       coalesce((p_verification_checks->>'tag_count')::boolean, false)
       and coalesce((p_verification_checks->>'tag_names')::boolean, false)
       and coalesce((p_verification_checks->>'tag_hierarchy')::boolean, false)
       and coalesce((p_verification_checks->>'assignment_count')::boolean, false)
       and coalesce((p_verification_checks->>'assignments')::boolean, false)
     ) then
    raise exception using
      errcode = '23514',
      message = 'Every Evernote tag verification check must be true.';
  end if;

  select *
  into v_state
  from public.evernote_tag_migrations
  where user_id = v_user_id
  for update;

  if not found or v_state.status not in ('imported', 'verified') then
    raise exception using
      errcode = '23514',
      message = 'Import the Evernote tag inventory before verifying it.';
  end if;

  select count(*)
  into v_tag_count
  from public.note_tags
  where user_id = v_user_id and source_system = 'evernote';

  select count(*)
  into v_assignment_count
  from public.note_tag_assignments
  where user_id = v_user_id and source_system = 'evernote';

  if v_tag_count <> v_state.source_tag_count
     or v_assignment_count <> v_state.source_assignment_count
     or exists (
       select 1
       from public.note_tags as child
       left join public.note_tags as parent
         on parent.id = child.parent_id
         and parent.user_id = child.user_id
       where child.user_id = v_user_id
         and child.source_system = 'evernote'
         and (
           nullif(
             btrim(coalesce(
               child.source_metadata->>'parent_source_key',
               ''
             )),
             ''
           ) is distinct from parent.source_key
         )
     ) then
    raise exception using
      errcode = '23514',
      message = 'Stored Evernote tags do not match the fixed hierarchy.';
  end if;

  update public.note_tags
  set verified_at = clock_timestamp(), updated_at = clock_timestamp()
  where user_id = v_user_id and source_system = 'evernote';

  update public.note_tag_assignments
  set verified_at = clock_timestamp()
  where user_id = v_user_id and source_system = 'evernote';

  update public.evernote_tag_migrations
  set
    status = 'verified',
    verified_tag_count = v_tag_count,
    verified_assignment_count = v_assignment_count,
    verification_checks = p_verification_checks,
    verified_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where user_id = v_user_id;

  return jsonb_build_object(
    'status', 'verified',
    'source_snapshot_sha256', v_state.source_snapshot_sha256,
    'tag_count', v_tag_count,
    'assignment_count', v_assignment_count
  );
end
$$;

create or replace function
  evernote_migration_private.enforce_tags_before_source_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('source_deleting', 'source_deleted')
     and not exists (
       select 1
       from public.evernote_tag_migrations
       where user_id = new.user_id
         and status in ('verified', 'source_deleted')
     ) then
    raise exception using
      errcode = '23514',
      message =
        'Evernote nested tags and note assignments must be inventoried and verified before source deletion.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.enforce_tags_before_source_deletion()
  from public, anon, authenticated, service_role;

create trigger enforce_evernote_tags_before_source_deletion
  before insert or update of status
  on public.evernote_migration_items
  for each row
  execute function
    evernote_migration_private.enforce_tags_before_source_deletion();

revoke all on function public.evernote_commit_tag_inventory(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.evernote_verify_tag_inventory(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.evernote_commit_tag_inventory(jsonb)
  to authenticated;
grant execute on function public.evernote_verify_tag_inventory(jsonb)
  to authenticated;

comment on table public.note_tags is
  'Owner-scoped native tags with loss-preserving Evernote parent hierarchy.';
comment on table public.note_tag_assignments is
  'Owner-scoped native note/tag assignments with immutable Evernote evidence.';
comment on table public.evernote_tag_migrations is
  'Fixed account tag inventory and verification gate for staged deletion.';
