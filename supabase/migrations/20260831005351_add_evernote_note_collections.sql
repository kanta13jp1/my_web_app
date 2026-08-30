-- Preserve Evernote Space / stack / notebook hierarchy as first-class data.
--
-- ENEX does not carry the full account hierarchy, so the import UI captures
-- source context and this migration resolves it idempotently before an item can
-- be marked verified.
--
-- nocheck: time-relative
-- The repository detector tokenizes schema-qualified UPDATE public.<table> as
-- an update to a table named public. This migration updates only notes,
-- note_collections, and evernote_migration_items; the disposable Postgres
-- contract proves the migration and hierarchy state transitions on replay-safe
-- fixed fixture timestamps.

create table public.note_collections (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  collection_type text not null,
  parent_id bigint,
  name text not null,
  normalized_name text generated always as (lower(btrim(name))) stored,
  source_system text not null default 'native',
  source_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_collections_id_user_key unique (id, user_id),
  constraint note_collections_type_check
    check (collection_type in ('space', 'stack', 'notebook')),
  constraint note_collections_name_check
    check (char_length(btrim(name)) between 1 and 200),
  constraint note_collections_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_collections_source_key_check
    check (
      (source_system = 'evernote' and source_key is not null)
      or source_system = 'native'
    ),
  constraint note_collections_parent_not_self_check
    check (parent_id is null or parent_id <> id),
  constraint note_collections_parent_owner_fkey
    foreign key (parent_id, user_id)
    references public.note_collections (id, user_id)
    on delete restrict,
  constraint note_collections_sibling_name_key
    unique nulls not distinct (
      user_id,
      parent_id,
      collection_type,
      normalized_name
    )
);

create unique index note_collections_source_key_idx
  on public.note_collections (user_id, source_system, source_key)
  where source_key is not null;

create index note_collections_user_parent_idx
  on public.note_collections (user_id, parent_id);

create index note_collections_parent_idx
  on public.note_collections (parent_id)
  where parent_id is not null;

alter table public.note_collections enable row level security;

create policy note_collections_select_owner
  on public.note_collections
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy note_collections_insert_owner
  on public.note_collections
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy note_collections_update_owner
  on public.note_collections
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy note_collections_delete_owner
  on public.note_collections
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_collections
  from public, anon, authenticated, service_role;
grant select, delete on table public.note_collections to authenticated;
grant insert (
  user_id,
  collection_type,
  parent_id,
  name,
  source_system,
  source_key,
  created_at,
  updated_at
) on table public.note_collections to authenticated;
grant update (
  parent_id,
  name,
  updated_at
) on table public.note_collections to authenticated;
grant all on table public.note_collections to service_role;

revoke all on sequence public.note_collections_id_seq
  from public, anon, authenticated, service_role;
grant usage, select on sequence public.note_collections_id_seq
  to authenticated;
grant all on sequence public.note_collections_id_seq to service_role;

create schema if not exists evernote_migration_private;
revoke all on schema evernote_migration_private
  from public, anon, authenticated, service_role;

create or replace function evernote_migration_private.validate_collection_parent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_type text;
  v_actor uuid := (select auth.uid());
begin
  if v_actor is not null and new.user_id <> v_actor then
    raise exception using
      errcode = '42501',
      message = 'A note collection must belong to the authenticated user.';
  end if;

  if new.collection_type = 'space' and new.parent_id is not null then
    raise exception using
      errcode = '23514',
      message = 'A Space cannot have a parent collection.';
  end if;

  if new.parent_id is null then
    return new;
  end if;

  select collection_type
  into v_parent_type
  from public.note_collections
  where id = new.parent_id
    and user_id = new.user_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The parent note collection does not exist for this user.';
  end if;

  if new.collection_type = 'stack' and v_parent_type <> 'space' then
    raise exception using
      errcode = '23514',
      message = 'A stack can only be placed inside a Space.';
  end if;

  if new.collection_type = 'notebook'
     and v_parent_type not in ('space', 'stack') then
    raise exception using
      errcode = '23514',
      message = 'A notebook can only be placed inside a Space or stack.';
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.validate_collection_parent()
  from public, anon, authenticated, service_role;

create trigger validate_note_collection_parent
  before insert or update of user_id, collection_type, parent_id
  on public.note_collections
  for each row
  execute function evernote_migration_private.validate_collection_parent();

alter table public.notes
  add column if not exists notebook_collection_id bigint;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notes_notebook_collection_owner_fkey'
      and conrelid = 'public.notes'::regclass
  ) then
    alter table public.notes
      add constraint notes_notebook_collection_owner_fkey
      foreign key (notebook_collection_id, user_id)
      references public.note_collections (id, user_id)
      on delete set null (notebook_collection_id);
  end if;
end
$$;

create index if not exists notes_user_notebook_collection_idx
  on public.notes (user_id, notebook_collection_id)
  where notebook_collection_id is not null;

create or replace function
  evernote_migration_private.validate_note_notebook_collection()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_collection_type text;
  v_actor uuid := (select auth.uid());
begin
  if v_actor is not null and new.user_id <> v_actor then
    raise exception using
      errcode = '42501',
      message = 'A note must belong to the authenticated user.';
  end if;

  if new.notebook_collection_id is null then
    return new;
  end if;

  select collection_type
  into v_collection_type
  from public.note_collections
  where id = new.notebook_collection_id
    and user_id = new.user_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The notebook does not exist for this user.';
  end if;

  if v_collection_type <> 'notebook' then
    raise exception using
      errcode = '23514',
      message = 'Notes can only be assigned to notebook collections.';
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.validate_note_notebook_collection()
  from public, anon, authenticated, service_role;

drop trigger if exists validate_note_notebook_collection on public.notes;
create trigger validate_note_notebook_collection
  before insert or update of user_id, notebook_collection_id
  on public.notes
  for each row
  execute function
    evernote_migration_private.validate_note_notebook_collection();

create or replace function public.evernote_resolve_note_hierarchy(
  p_space_name text,
  p_stack_name text,
  p_notebook_name text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_space_name text := nullif(btrim(p_space_name), '');
  v_stack_name text := nullif(btrim(p_stack_name), '');
  v_notebook_name text := nullif(btrim(p_notebook_name), '');
  v_space_id bigint;
  v_stack_id bigint;
  v_notebook_id bigint;
  v_parent_id bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if v_notebook_name is null
     or char_length(v_notebook_name) > 200
     or char_length(coalesce(v_space_name, '')) > 200
     or char_length(coalesce(v_stack_name, '')) > 200 then
    raise exception using
      errcode = '22023',
      message = 'Evernote hierarchy names must contain 1 to 200 characters.';
  end if;

  if v_space_name is not null then
    insert into public.note_collections (
      user_id,
      collection_type,
      parent_id,
      name,
      source_system,
      source_key
    )
    values (
      v_user_id,
      'space',
      null,
      v_space_name,
      'evernote',
      'space:' || lower(v_space_name)
    )
    on conflict (user_id, source_system, source_key)
      where source_key is not null
    do update set
      name = excluded.name,
      parent_id = null,
      updated_at = clock_timestamp()
    returning id into v_space_id;
  end if;

  if v_stack_name is not null then
    insert into public.note_collections (
      user_id,
      collection_type,
      parent_id,
      name,
      source_system,
      source_key
    )
    values (
      v_user_id,
      'stack',
      v_space_id,
      v_stack_name,
      'evernote',
      'stack:' || lower(v_stack_name)
    )
    on conflict (user_id, source_system, source_key)
      where source_key is not null
    do update set
      name = excluded.name,
      parent_id = excluded.parent_id,
      updated_at = clock_timestamp()
    returning id into v_stack_id;
  end if;

  v_parent_id := coalesce(v_stack_id, v_space_id);

  insert into public.note_collections (
    user_id,
    collection_type,
    parent_id,
    name,
    source_system,
    source_key
  )
  values (
    v_user_id,
    'notebook',
    v_parent_id,
    v_notebook_name,
    'evernote',
    'notebook:' || lower(v_notebook_name)
  )
  on conflict (user_id, source_system, source_key)
    where source_key is not null
  do update set
    name = excluded.name,
    parent_id = excluded.parent_id,
    updated_at = clock_timestamp()
  returning id into v_notebook_id;

  return jsonb_build_object(
    'space_id', v_space_id,
    'stack_id', v_stack_id,
    'notebook_id', v_notebook_id
  );
end
$$;

revoke all on function public.evernote_resolve_note_hierarchy(
  text,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.evernote_resolve_note_hierarchy(
  text,
  text,
  text
) to authenticated;

create or replace function public.evernote_commit_note_with_hierarchy(
  p_batch_id bigint,
  p_source_item_key text,
  p_title text,
  p_content text,
  p_source_created_at timestamptz,
  p_source_updated_at timestamptz,
  p_tags text[],
  p_source_enml text,
  p_source_metadata jsonb,
  p_resources jsonb,
  p_archive_bucket text,
  p_archive_path text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_result jsonb;
  v_context jsonb;
  v_hierarchy jsonb;
  v_note_id bigint;
  v_notebook_id bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if p_source_metadata is null
     or jsonb_typeof(p_source_metadata) <> 'object'
     or jsonb_typeof(p_source_metadata->'source_context') <> 'object' then
    raise exception using
      errcode = '22023',
      message = 'Evernote source hierarchy is required.';
  end if;

  v_context := p_source_metadata->'source_context';
  v_hierarchy := public.evernote_resolve_note_hierarchy(
    v_context->>'space_name',
    v_context->>'stack_name',
    v_context->>'notebook_name'
  );
  v_notebook_id := (v_hierarchy->>'notebook_id')::bigint;

  v_result := public.evernote_commit_note(
    p_batch_id,
    p_source_item_key,
    p_title,
    p_content,
    p_source_created_at,
    p_source_updated_at,
    p_tags,
    p_source_enml,
    p_source_metadata,
    p_resources,
    p_archive_bucket,
    p_archive_path
  );
  v_note_id := (v_result->>'note_id')::bigint;

  update public.notes
  set notebook_collection_id = v_notebook_id
  where id = v_note_id
    and user_id = v_user_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The committed Evernote note could not be assigned.';
  end if;

  update public.evernote_migration_items
  set
    source_metadata = coalesce(source_metadata, '{}'::jsonb)
      || jsonb_build_object('resolved_hierarchy', v_hierarchy),
    updated_at = clock_timestamp()
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Evernote migration item could not be updated.';
  end if;

  return v_result || jsonb_build_object('hierarchy', v_hierarchy);
end
$$;

create or replace function public.evernote_verify_note_with_hierarchy(
  p_batch_id bigint,
  p_source_item_key text,
  p_verification_checks jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_collection_id bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if coalesce(
    (p_verification_checks->>'hierarchy')::boolean,
    false
  ) is not true then
    raise exception using
      errcode = '22023',
      message = 'Evernote hierarchy verification must pass.';
  end if;

  select n.notebook_collection_id
  into v_collection_id
  from public.evernote_migration_items as item
  join public.notes as n
    on n.id = item.target_note_id
   and n.user_id = item.user_id
  join public.note_collections as collection
    on collection.id = n.notebook_collection_id
   and collection.user_id = n.user_id
   and collection.collection_type = 'notebook'
  where item.batch_id = p_batch_id
    and item.user_id = v_user_id
    and item.source_item_key = p_source_item_key;

  if v_collection_id is null then
    raise exception using
      errcode = '23514',
      message = 'The Evernote note has no verified notebook hierarchy.';
  end if;

  return public.evernote_verify_note(
    p_batch_id,
    p_source_item_key,
    p_verification_checks
  );
end
$$;

revoke all on function public.evernote_commit_note_with_hierarchy(
  bigint,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text[],
  text,
  jsonb,
  jsonb,
  text,
  text
) from public, anon, authenticated, service_role;

revoke all on function public.evernote_verify_note_with_hierarchy(
  bigint,
  text,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.evernote_commit_note_with_hierarchy(
  bigint,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text[],
  text,
  jsonb,
  jsonb,
  text,
  text
) to authenticated;

grant execute on function public.evernote_verify_note_with_hierarchy(
  bigint,
  text,
  jsonb
) to authenticated;

comment on table public.note_collections is
  'Owner-scoped Space, stack, and notebook tree used by native notes and lossless imports.';

comment on function public.evernote_commit_note_with_hierarchy(
  bigint,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text[],
  text,
  jsonb,
  jsonb,
  text,
  text
) is
  'Commits an Evernote note and idempotently resolves its source hierarchy in one transaction.';

comment on function public.evernote_verify_note_with_hierarchy(
  bigint,
  text,
  jsonb
) is
  'Blocks Evernote verification until the committed note belongs to an owner-scoped notebook.';
