\set ON_ERROR_STOP on

-- The hierarchy contract created both fixture users and the first imported note.
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

select public.evernote_commit_navigation_inventory(
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'saved:project',
      'name', 'Project notes',
      'query', 'tag:project'
    )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'shortcut:saved-project',
      'position', 1,
      'target_type', 'saved_search',
      'target_source_key', 'saved:project',
      'label', 'Project notes'
    ),
    jsonb_build_object(
      'source_key', 'shortcut:tag-project',
      'position', 2,
      'target_type', 'tag',
      'target_tag', 'project',
      'label', 'Project'
    )
  )
);

-- Exact replay is idempotent.
select public.evernote_commit_navigation_inventory(
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'saved:project',
      'name', 'Project notes',
      'query', 'tag:project'
    )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'shortcut:saved-project',
      'position', 1,
      'target_type', 'saved_search',
      'target_source_key', 'saved:project',
      'label', 'Project notes'
    ),
    jsonb_build_object(
      'source_key', 'shortcut:tag-project',
      'position', 2,
      'target_type', 'tag',
      'target_tag', 'project',
      'label', 'Project'
    )
  )
);

do $$
begin
  if (
    select count(*)
    from public.note_saved_searches
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'Saved-search replay created a duplicate.';
  end if;
  if (
    select count(*)
    from public.note_shortcuts
    where source_system = 'evernote'
  ) <> 2 then
    raise exception 'Shortcut replay created a duplicate.';
  end if;
  if (
    select char_length(source_snapshot_sha256)
    from public.evernote_navigation_migrations
    where user_id = '00000000-0000-4000-8000-000000000101'
  ) <> 64 then
    raise exception 'Navigation snapshot hash was not retained.';
  end if;
  if exists (
    select 1
    from public.note_shortcuts
    where target_type = 'saved_search'
      and target_saved_search_id is null
  ) then
    raise exception 'Saved-search shortcut target was not resolved.';
  end if;
end
$$;

do $$
begin
  begin
    perform public.evernote_verify_navigation_inventory(
      jsonb_build_object(
        'saved_search_count', true,
        'saved_search_queries', true,
        'shortcut_count', true,
        'shortcut_order', true,
        'shortcut_targets', false
      )
    );
    raise exception 'Incomplete verification unexpectedly succeeded.';
  exception
    when check_violation then
      null;
  end;
end
$$;

select public.evernote_verify_navigation_inventory(
  jsonb_build_object(
    'saved_search_count', true,
    'saved_search_queries', true,
    'shortcut_count', true,
    'shortcut_order', true,
    'shortcut_targets', true
  )
);

do $$
begin
  if (
    select status
    from public.evernote_navigation_migrations
    where user_id = '00000000-0000-4000-8000-000000000101'
  ) <> 'verified' then
    raise exception 'Navigation verification state was not stored.';
  end if;

  begin
    update public.note_saved_searches
    set query = 'tag:changed'
    where source_system = 'evernote';
    raise exception 'Imported saved-search evidence was mutable.';
  exception
    when check_violation then
      null;
  end;

  begin
    delete from public.note_shortcuts
    where source_system = 'evernote'
      and source_key = 'shortcut:tag-project';
    raise exception 'Imported shortcut evidence was deletable.';
  exception
    when check_violation then
      null;
  end;
end
$$;

-- Native CRUD and deterministic reordering remain available.
insert into public.note_saved_searches (
  user_id,
  name,
  query
)
values (
  '00000000-0000-4000-8000-000000000101',
  'Native recent',
  'updated:day-7'
);

insert into public.note_shortcuts (
  user_id,
  position,
  target_type,
  target_tag,
  target_label
)
values
(
  '00000000-0000-4000-8000-000000000101',
  3,
  'tag',
  'native-a',
  'Native A'
),
(
  '00000000-0000-4000-8000-000000000101',
  4,
  'tag',
  'native-b',
  'Native B'
);

select public.note_shortcut_move(
  (
    select id
    from public.note_shortcuts
    where user_id = '00000000-0000-4000-8000-000000000101'
      and target_label = 'Native B'
  ),
  3
);

do $$
begin
  if (
    select position
    from public.note_shortcuts
    where target_label = 'Native B'
  ) <> 3 or (
    select position
    from public.note_shortcuts
    where target_label = 'Native A'
  ) <> 4 then
    raise exception 'Native shortcut reorder did not preserve unique order.';
  end if;
end
$$;

-- A second owner cannot see or target the first owner's navigation state.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
declare
  v_owner_note_id bigint := 1;
begin
  if (select count(*) from public.note_saved_searches) <> 0
     or (select count(*) from public.note_shortcuts) <> 0
     or (select count(*) from public.evernote_navigation_migrations) <> 0 then
    raise exception 'Owner-scoped RLS leaked navigation state.';
  end if;


  begin
    insert into public.note_shortcuts (
      user_id,
      position,
      target_type,
      target_note_id,
      target_label
    )
    values (
      '00000000-0000-4000-8000-000000000102',
      1,
      'note',
      v_owner_note_id,
      'Cross-owner'
    );
    raise exception 'Cross-owner shortcut target unexpectedly succeeded.';
  exception
    when foreign_key_violation or insufficient_privilege then
      null;
  end;
end
$$;

insert into public.notes (user_id, title, content)
values (
  '00000000-0000-4000-8000-000000000102',
  'Navigation gate fixture',
  'Body'
);

insert into public.evernote_migration_items (
  batch_id,
  user_id,
  source_item_key,
  target_note_id,
  status,
  history_status,
  task_status
)
select
  104,
  '00000000-0000-4000-8000-000000000102',
  'id:note-104',
  id,
  'verified',
  'reviewed_no_versions',
  'verified_no_features'
from public.notes
where user_id = '00000000-0000-4000-8000-000000000102'
  and title = 'Navigation gate fixture';

do $$
begin
  begin
    update public.evernote_migration_items
    set status = 'source_deleting'
    where batch_id = 104;
    raise exception 'Missing navigation inventory did not block deletion.';
  exception
    when check_violation then
      if sqlerrm not like '%saved searches and shortcuts%' then
        raise;
      end if;
  end;
end
$$;

-- Explicitly recording and verifying an empty account inventory is valid.
select public.evernote_commit_navigation_inventory('[]'::jsonb, '[]'::jsonb);
select public.evernote_verify_navigation_inventory(
  jsonb_build_object(
    'saved_search_count', true,
    'saved_search_queries', true,
    'shortcut_count', true,
    'shortcut_order', true,
    'shortcut_targets', true
  )
);

update public.evernote_migration_items
set status = 'source_deleting'
where batch_id = 104;

reset role;

set role anon;
do $$
begin
  begin
    perform count(*) from public.note_saved_searches;
    raise exception 'Anonymous role unexpectedly read saved searches.';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;
reset role;
