\set ON_ERROR_STOP on

insert into auth.users (id, email)
values
  (
    '00000000-0000-4000-8000-000000000101',
    'owner@example.com'
  ),
  (
    '00000000-0000-4000-8000-000000000102',
    'delegate@example.com'
  );

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

select public.evernote_commit_note_with_features(
  101,
  'id:note-101',
  'Hierarchy fixture',
  'Body',
  '2026-08-31T00:00:00Z',
  '2026-08-31T00:01:00Z',
  array['migration'],
  '<en-note>Body</en-note>',
  jsonb_build_object(
    'source_context',
    jsonb_build_object(
      'space_name', 'Space A',
      'stack_name', 'Stack A',
      'notebook_name', 'Notebook A'
    )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'title', 'Structured task',
      'created_at', '2026-08-31T00:00:10Z',
      'updated_at', '2026-08-31T00:00:20Z',
      'status', 'open',
      'in_note', true,
      'task_flag', 'false',
      'sort_weight', '1',
      'note_level_id', 'task-101',
      'task_group_note_level_id', 'group-101',
      'due_at', '2026-09-01T00:00:00Z',
      'due_date_ui_option', 'date_time',
      'time_zone', 'Asia/Tokyo',
      'recurrence', 'FREQ=DAILY',
      'repeat_after_completion', false,
      'status_updated_at', null,
      'creator', 'fixture',
      'last_editor', 'fixture',
      'assignee', jsonb_build_object(
        'user_id', 'evernote-user-42',
        'email', 'delegate@example.com',
        'display_name', 'Delegated reviewer',
        'raw_xml', '<assignee>delegate@example.com</assignee>'
      ),
      'source_sha256', repeat('e', 64),
      'raw_xml', '<task>Structured task</task>',
      'reminders', jsonb_build_array(
        jsonb_build_object(
          'created_at', '2026-08-31T00:00:30Z',
          'updated_at', '2026-08-31T00:00:40Z',
          'note_level_id', 'task-reminder-101',
          'reminder_at', '2026-09-01T00:00:00Z',
          'reminder_date_ui_option', 'date_time',
          'time_zone', 'Asia/Tokyo',
          'due_date_offset', '0',
          'status', 'active',
          'source_sha256', repeat('f', 64),
          'raw_xml', '<reminder />'
        )
      )
    )
  ),
  jsonb_build_object(
    'order', 1,
    'reminder_at', '2026-09-02T00:00:00Z',
    'completed_at', null,
    'source_sha256', repeat('d', 64)
  ),
  '[]'::jsonb,
  'evernote-migration-archives',
  'fixture/source.enex'
);

do $$
declare
  v_space_id bigint;
  v_stack_id bigint;
  v_notebook_id bigint;
  v_note_notebook_id bigint;
begin
  select id into strict v_space_id
  from public.note_collections
  where collection_type = 'space'
    and name = 'Space A';

  select id into strict v_stack_id
  from public.note_collections
  where collection_type = 'stack'
    and name = 'Stack A'
    and parent_id = v_space_id;

  select id into strict v_notebook_id
  from public.note_collections
  where collection_type = 'notebook'
    and name = 'Notebook A'
    and parent_id = v_stack_id;

  select notebook_collection_id into strict v_note_notebook_id
  from public.notes
  where title = 'Hierarchy fixture';

  if v_note_notebook_id <> v_notebook_id then
    raise exception 'Committed note was not assigned to the resolved notebook.';
  end if;
end
$$;

-- A retry must reuse the same note and hierarchy rows.
select public.evernote_commit_note_with_features(
  101,
  'id:note-101',
  'Hierarchy fixture',
  'Body',
  '2026-08-31T00:00:00Z',
  '2026-08-31T00:01:00Z',
  array['migration'],
  '<en-note>Body</en-note>',
  jsonb_build_object(
    'source_context',
    jsonb_build_object(
      'space_name', 'Space A',
      'stack_name', 'Stack A',
      'notebook_name', 'Notebook A'
    )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'title', 'Structured task',
      'created_at', '2026-08-31T00:00:10Z',
      'updated_at', '2026-08-31T00:00:20Z',
      'status', 'open',
      'in_note', true,
      'task_flag', 'false',
      'sort_weight', '1',
      'note_level_id', 'task-101',
      'task_group_note_level_id', 'group-101',
      'due_at', '2026-09-01T00:00:00Z',
      'due_date_ui_option', 'date_time',
      'time_zone', 'Asia/Tokyo',
      'recurrence', 'FREQ=DAILY',
      'repeat_after_completion', false,
      'status_updated_at', null,
      'creator', 'fixture',
      'last_editor', 'fixture',
      'assignee', jsonb_build_object(
        'user_id', 'evernote-user-42',
        'email', 'delegate@example.com',
        'display_name', 'Delegated reviewer',
        'raw_xml', '<assignee>delegate@example.com</assignee>'
      ),
      'source_sha256', repeat('e', 64),
      'raw_xml', '<task>Structured task</task>',
      'reminders', jsonb_build_array(
        jsonb_build_object(
          'created_at', '2026-08-31T00:00:30Z',
          'updated_at', '2026-08-31T00:00:40Z',
          'note_level_id', 'task-reminder-101',
          'reminder_at', '2026-09-01T00:00:00Z',
          'reminder_date_ui_option', 'date_time',
          'time_zone', 'Asia/Tokyo',
          'due_date_offset', '0',
          'status', 'active',
          'source_sha256', repeat('f', 64),
          'raw_xml', '<reminder />'
        )
      )
    )
  ),
  jsonb_build_object(
    'order', 1,
    'reminder_at', '2026-09-02T00:00:00Z',
    'completed_at', null,
    'source_sha256', repeat('d', 64)
  ),
  '[]'::jsonb,
  'evernote-migration-archives',
  'fixture/source.enex'
);

do $$
begin
  if (select count(*) from public.note_collections) <> 3 then
    raise exception 'Hierarchy retry created duplicate collections.';
  end if;
  if (select count(*) from public.notes) <> 1 then
    raise exception 'Hierarchy retry created a duplicate note.';
  end if;
end
$$;

select public.evernote_verify_note_with_features(
  101,
  'id:note-101',
  jsonb_build_object(
    'archive_sha256', true,
    'note_content', true,
    'timestamps', true,
    'tags', true,
    'resource_count', true,
    'resource_sha256', true,
    'hierarchy', true,
    'task_count', true,
    'task_hashes', true,
    'task_reminder_hashes', true,
    'note_reminder_hash', true
  )
);

do $$
begin
  if (
    select status
    from public.evernote_migration_items
    where batch_id = 101
      and source_item_key = 'id:note-101'
  ) <> 'verified' then
    raise exception 'Hierarchy-gated verification did not complete.';
  end if;
end
$$;

-- A note cannot be assigned to a Space instead of a notebook.
do $$
declare
  v_space_id bigint;
begin
  select id into strict v_space_id
  from public.note_collections
  where collection_type = 'space';

  begin
    update public.notes
    set notebook_collection_id = v_space_id
    where title = 'Hierarchy fixture';
    raise exception 'A Space was accepted as a notebook.';
  exception
    when check_violation then
      null;
  end;
end
$$;

-- Another authenticated user must see no collections and cannot forge owner_id.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_collections) <> 0 then
    raise exception 'RLS exposed another user hierarchy.';
  end if;

  begin
    insert into public.note_collections (
      user_id,
      collection_type,
      name,
      source_system,
      source_key
    )
    values (
      '00000000-0000-4000-8000-000000000101',
      'notebook',
      'Forged',
      'evernote',
      'notebook:forged'
    );
    raise exception 'Cross-owner hierarchy insert unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

reset role;
