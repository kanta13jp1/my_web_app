-- Add native management semantics to the owner-scoped note collection tree.
--
-- Evernote imported names and membership edges remain immutable until every
-- migration item for the owner has reached source_deleted. Operational state
-- (pin, order, and default notebook) stays editable because it is native state.
--
-- nocheck: time-relative
-- Fixed timestamps are not used; clock_timestamp() records user-driven changes.

alter table public.note_collections
  add column if not exists description text not null default '',
  add column if not exists sort_order integer not null default 0,
  add column if not exists is_default boolean not null default false,
  add column if not exists is_pinned boolean not null default false;

alter table public.note_collections
  add constraint note_collections_description_check
    check (char_length(description) <= 2000),
  add constraint note_collections_sort_order_check
    check (sort_order between 0 and 1000000),
  add constraint note_collections_default_type_check
    check (not is_default or collection_type = 'notebook');

create unique index note_collections_one_default_per_owner_idx
  on public.note_collections (user_id)
  where is_default;

create index note_collections_owner_tree_order_idx
  on public.note_collections (
    user_id,
    parent_id,
    collection_type,
    is_pinned desc,
    sort_order,
    normalized_name
  );

grant update (
  description,
  sort_order,
  is_default,
  is_pinned
) on table public.note_collections to authenticated;

-- Destructive actions must pass the RPC below so notebook notes are archived
-- atomically instead of being detached by the foreign-key ON DELETE behavior.
revoke delete on table public.note_collections from authenticated;

create or replace function
  evernote_migration_private.collection_source_deleted(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1
      from public.evernote_migration_items
      where user_id = p_user_id
    )
    and not exists (
      select 1
      from public.evernote_migration_items
      where user_id = p_user_id
        and status <> 'source_deleted'
    );
$$;

revoke all on function
  evernote_migration_private.collection_source_deleted(uuid)
  from public, anon, authenticated, service_role;

create or replace function
  evernote_migration_private.protect_note_collection_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_source_changed boolean;
begin
  if v_actor is not null and old.user_id <> v_actor then
    raise exception using
      errcode = '42501',
      message = 'A note collection must belong to the authenticated user.';
  end if;

  if tg_op = 'DELETE' then
    if old.is_default then
      raise exception using
        errcode = '23514',
        message = 'The default notebook cannot be deleted.';
    end if;
    v_source_changed := true;
  else
    v_source_changed :=
      new.user_id is distinct from old.user_id
      or new.collection_type is distinct from old.collection_type
      or new.parent_id is distinct from old.parent_id
      or new.name is distinct from old.name
      or new.source_system is distinct from old.source_system
      or new.source_key is distinct from old.source_key;
  end if;

  if v_actor is not null
     and old.source_system = 'evernote'
     and v_source_changed
     and not evernote_migration_private.collection_source_deleted(old.user_id)
  then
    raise exception using
      errcode = '55000',
      message =
        'Evernote collection evidence is locked until source deletion is verified.';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.protect_note_collection_source()
  from public, anon, authenticated, service_role;

drop trigger if exists protect_note_collection_source
  on public.note_collections;
create trigger protect_note_collection_source
  before update or delete
  on public.note_collections
  for each row
  execute function
    evernote_migration_private.protect_note_collection_source();

create or replace function public.set_default_note_collection(
  p_collection_id bigint
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  perform 1
  from public.note_collections
  where id = p_collection_id
    and user_id = v_user_id
    and collection_type = 'notebook';

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The notebook does not exist for this user.';
  end if;

  update public.note_collections
  set
    is_default = (id = p_collection_id),
    updated_at = clock_timestamp()
  where user_id = v_user_id
    and collection_type = 'notebook'
    and is_default is distinct from (id = p_collection_id);
end
$$;

revoke all on function public.set_default_note_collection(bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.set_default_note_collection(bigint)
  to authenticated;

create or replace function public.delete_note_collection(
  p_collection_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_type text;
  v_name text;
  v_archived_notes integer := 0;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  select collection_type, name
  into v_type, v_name
  from public.note_collections
  where id = p_collection_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The note collection does not exist for this user.';
  end if;

  if exists (
    select 1
    from public.note_collections
    where user_id = v_user_id
      and parent_id = p_collection_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'Move child collections before deleting this collection.';
  end if;

  if v_type = 'notebook' then
    update public.notes
    set
      is_archived = true,
      updated_at = clock_timestamp()
    where user_id = v_user_id
      and notebook_collection_id = p_collection_id
      and not is_archived;
    get diagnostics v_archived_notes = row_count;
  end if;

  delete from public.note_collections
  where id = p_collection_id
    and user_id = v_user_id;

  return jsonb_build_object(
    'collection_id', p_collection_id,
    'collection_type', v_type,
    'name', v_name,
    'archived_note_count', v_archived_notes
  );
end
$$;

revoke all on function public.delete_note_collection(bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.delete_note_collection(bigint)
  to authenticated;

comment on function public.set_default_note_collection(bigint) is
  'Atomically marks one owner-scoped notebook as the default notebook.';

comment on function public.delete_note_collection(bigint) is
  'Deletes one owner-scoped native collection and archives notebook notes atomically. Imported evidence and default notebooks remain protected.';
