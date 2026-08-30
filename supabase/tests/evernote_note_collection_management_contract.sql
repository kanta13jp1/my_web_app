\set ON_ERROR_STOP on

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

insert into public.note_collections (
  user_id,
  collection_type,
  name,
  description,
  source_system,
  sort_order
)
values
  (
    '00000000-0000-4000-8000-000000000101',
    'space',
    'Native Space',
    'Project workspace',
    'native',
    10
  ),
  (
    '00000000-0000-4000-8000-000000000101',
    'stack',
    'Native Stack',
    '',
    'native',
    20
  );

insert into public.note_collections (
  user_id,
  collection_type,
  parent_id,
  name,
  source_system,
  sort_order
)
select
  '00000000-0000-4000-8000-000000000101',
  'notebook',
  id,
  'Primary Notebook',
  'native',
  10
from public.note_collections
where user_id = '00000000-0000-4000-8000-000000000101'
  and name = 'Native Stack';

insert into public.note_collections (
  user_id,
  collection_type,
  name,
  source_system,
  sort_order
)
values (
  '00000000-0000-4000-8000-000000000101',
  'notebook',
  'Disposable Notebook',
  'native',
  20
);

select public.set_default_note_collection(
  (
    select id
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Primary Notebook'
  )
);

do $$
begin
  if (
    select count(*)
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and is_default
  ) <> 1 then
    raise exception 'Exactly one default notebook was not retained.';
  end if;

  if not (
    select is_default
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Primary Notebook'
  ) then
    raise exception 'The requested notebook was not marked as default.';
  end if;

  if has_table_privilege(
    'authenticated',
    'public.note_collections',
    'delete'
  ) then
    raise exception 'Authenticated users retained direct collection delete.';
  end if;
end
$$;

update public.note_collections
set
  is_pinned = true,
  sort_order = 1
where user_id = '00000000-0000-4000-8000-000000000101'
  and name = 'Native Space';

do $$
begin
  if not (
    select is_pinned and sort_order = 1
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Native Space'
  ) then
    raise exception 'Native pin or order update failed.';
  end if;
end
$$;

-- Imported source hierarchy is immutable while its source item is verified but
-- not yet explicitly deleted in Evernote.
do $$
begin
  begin
    update public.note_collections
    set name = 'Changed imported Space'
    where user_id = '00000000-0000-4000-8000-000000000101'
      and collection_type = 'space'
      and name = 'Space A';
    raise exception 'Imported collection rename unexpectedly succeeded.';
  exception
    when object_not_in_prerequisite_state then
      null;
  end;

  begin
    perform public.delete_note_collection(
      (
        select id
        from public.note_collections
        where user_id = '00000000-0000-4000-8000-000000000101'
          and collection_type = 'notebook'
          and name = 'Notebook A'
      )
    );
    raise exception 'Imported collection delete unexpectedly succeeded.';
  exception
    when object_not_in_prerequisite_state then
      null;
  end;
end
$$;

-- A default notebook cannot be deleted, even through the guarded RPC.
do $$
begin
  begin
    perform public.delete_note_collection(
      (
        select id
        from public.note_collections
        where user_id = '00000000-0000-4000-8000-000000000101'
          and name = 'Primary Notebook'
      )
    );
    raise exception 'Default notebook delete unexpectedly succeeded.';
  exception
    when check_violation then
      null;
  end;
end
$$;

insert into public.notes (
  user_id,
  title,
  content,
  notebook_collection_id
)
select
  '00000000-0000-4000-8000-000000000101',
  'Archive with notebook',
  'This note must move to trash.',
  id
from public.note_collections
where user_id = '00000000-0000-4000-8000-000000000101'
  and name = 'Disposable Notebook';

select public.delete_note_collection(
  (
    select id
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Disposable Notebook'
  )
);

do $$
begin
  if exists (
    select 1
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Disposable Notebook'
  ) then
    raise exception 'Native notebook was not deleted.';
  end if;

  if not (
    select is_archived and notebook_collection_id is null
    from public.notes
    where user_id = '00000000-0000-4000-8000-000000000101'
      and title = 'Archive with notebook'
  ) then
    raise exception 'Deleted notebook note was not archived and detached.';
  end if;
end
$$;

-- RLS and the guarded RPC still isolate another authenticated user.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_collections) <> 0 then
    raise exception 'Collection management exposed another owner.';
  end if;

  begin
    perform public.set_default_note_collection(
      (
        select id
        from public.note_collections
        where name = 'Primary Notebook'
      )
    );
    raise exception 'Cross-owner default change unexpectedly succeeded.';
  exception
    when no_data_found then
      null;
  end;
end
$$;

reset role;
