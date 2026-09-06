\set ON_ERROR_STOP on

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

select public.evernote_mark_note_history_reviewed(
  101,
  'id:note-101',
  1
);

insert into storage.objects (
  bucket_id,
  name,
  owner_id
)
values
(
  'evernote-migration-archives',
  '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/source.enex',
  '00000000-0000-4000-8000-000000000101'
),
(
  'attachments',
  '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/0000-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-fixture.txt',
  '00000000-0000-4000-8000-000000000101'
);

select public.evernote_commit_note_history_version(
  101,
  'id:note-101',
  'history:20240102T030405Z',
  'Historical title',
  'Historical body',
  '2024-01-02T03:04:05Z',
  '<en-note>Historical body</en-note>',
  array['history'],
  jsonb_build_object('raw_note_xml_sha256', repeat('c', 64)),
  jsonb_build_array(
    jsonb_build_object(
      'file_name', 'fixture.txt',
      'file_path',
        '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/0000-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-fixture.txt',
      'file_size', 18,
      'mime_type', 'text/plain',
      'content_sha256', repeat('b', 64),
      'source_metadata', jsonb_build_object('resource_index', 0)
    )
  ),
  'evernote-migration-archives',
  '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/source.enex',
  repeat('a', 64),
  repeat('d', 64)
);

do $$
begin
  if (
    select count(*)
    from public.note_versions
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'Evernote history version was not committed exactly once.';
  end if;

  if (
    select count(*)
    from public.evernote_note_history_attachments
  ) <> 1 then
    raise exception 'Evernote history attachment was not committed.';
  end if;

  if (
    select history_status
    from public.evernote_migration_items
    where batch_id = 101
      and source_item_key = 'id:note-101'
  ) <> 'imported' then
    raise exception 'History status did not advance to imported.';
  end if;
end
$$;

-- A retry must update the deterministic source row, not duplicate it.
select public.evernote_commit_note_history_version(
  101,
  'id:note-101',
  'history:20240102T030405Z',
  'Historical title',
  'Historical body',
  '2024-01-02T03:04:05Z',
  '<en-note>Historical body</en-note>',
  array['history'],
  jsonb_build_object('raw_note_xml_sha256', repeat('c', 64)),
  jsonb_build_array(
    jsonb_build_object(
      'file_name', 'fixture.txt',
      'file_path',
        '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/0000-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-fixture.txt',
      'file_size', 18,
      'mime_type', 'text/plain',
      'content_sha256', repeat('b', 64),
      'source_metadata', jsonb_build_object('resource_index', 0)
    )
  ),
  'evernote-migration-archives',
  '00000000-0000-4000-8000-000000000101/evernote-history/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/source.enex',
  repeat('a', 64),
  repeat('d', 64)
);

do $$
begin
  if (
    select count(*)
    from public.note_versions
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'History retry created a duplicate version.';
  end if;
  if (
    select count(*)
    from public.evernote_note_history_attachments
  ) <> 1 then
    raise exception 'History retry created a duplicate attachment.';
  end if;
end
$$;

select public.evernote_verify_note_history_version(
  101,
  'id:note-101',
  'history:20240102T030405Z',
  repeat('a', 64),
  jsonb_build_object(
    'archive_sha256', true,
    'content_sha256', true,
    'timestamp', true,
    'resource_count', true,
    'resource_sha256', true
  )
);

do $$
begin
  if (
    select history_status
    from public.evernote_migration_items
    where batch_id = 101
      and source_item_key = 'id:note-101'
  ) <> 'verified' then
    raise exception 'History verification gate did not complete.';
  end if;

  update public.evernote_migration_items
  set status = 'source_deleting'
  where batch_id = 101
    and source_item_key = 'id:note-101';
end
$$;

-- Pending history must block source deletion; explicit zero-version review
-- unlocks only that item.
insert into public.notes (user_id, title, content)
values (
  '00000000-0000-4000-8000-000000000101',
  'No-history fixture',
  'Body'
);

insert into public.evernote_migration_items (
  batch_id,
  user_id,
  source_item_key,
  target_note_id,
  status
)
select
  102,
  '00000000-0000-4000-8000-000000000101',
  'id:note-102',
  id,
  'verified'
from public.notes
where title = 'No-history fixture';

do $$
begin
  begin
    update public.evernote_migration_items
    set status = 'source_deleting'
    where batch_id = 102
      and source_item_key = 'id:note-102';
    raise exception 'Pending history did not block source deletion.';
  exception
    when check_violation then
      null;
  end;
end
$$;

select public.evernote_mark_note_history_reviewed(
  102,
  'id:note-102',
  0
);

select public.evernote_verify_note_features(
  102,
  'id:note-102',
  jsonb_build_object(
    'task_count', true,
    'task_hashes', true,
    'task_reminder_hashes', true,
    'note_reminder_hash', true
  )
);

update public.evernote_migration_items
set status = 'source_deleting'
where batch_id = 102
  and source_item_key = 'id:note-102';

do $$
begin
  if (
    select history_status
    from public.evernote_migration_items
    where batch_id = 102
      and source_item_key = 'id:note-102'
  ) <> 'reviewed_no_versions' then
    raise exception 'Explicit zero-version review was not preserved.';
  end if;
end
$$;

-- Another authenticated user must see neither history nor attachments.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_versions) <> 0 then
    raise exception 'RLS exposed another user note history.';
  end if;
  if (
    select count(*)
    from public.evernote_note_history_attachments
  ) <> 0 then
    raise exception 'RLS exposed another user history attachments.';
  end if;
end
$$;

reset role;
