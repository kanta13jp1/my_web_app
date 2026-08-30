\set ON_ERROR_STOP on

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

do $$
begin
  if (
    select count(*)
    from public.note_tasks
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'Evernote Task was not committed exactly once.';
  end if;

  if (
    select count(*)
    from public.note_task_reminders
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'Evernote Task reminder was not committed exactly once.';
  end if;

  if (
    select count(*)
    from public.note_reminders
    where source_system = 'evernote'
  ) <> 1 then
    raise exception 'Evernote note reminder was not committed exactly once.';
  end if;

  if (
    select source_sha256
    from public.note_tasks
    where source_system = 'evernote'
  ) <> repeat('e', 64) then
    raise exception 'Evernote Task source hash was not preserved.';
  end if;

  if (
    select source_sha256
    from public.note_task_reminders
    where source_system = 'evernote'
  ) <> repeat('f', 64) then
    raise exception 'Evernote Task reminder source hash was not preserved.';
  end if;

  if (
    select source_sha256
    from public.note_reminders
    where source_system = 'evernote'
  ) <> repeat('d', 64) then
    raise exception 'Evernote note reminder source hash was not preserved.';
  end if;

  if (
    select task_status
    from public.evernote_migration_items
    where batch_id = 101
      and source_item_key = 'id:note-101'
  ) <> 'verified' then
    raise exception 'Evernote Task verification gate did not complete.';
  end if;
end
$$;

-- Another authenticated user must see no Task/reminder rows and cannot
-- forge ownership.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_tasks) <> 0 then
    raise exception 'RLS exposed another user Tasks.';
  end if;
  if (select count(*) from public.note_task_reminders) <> 0 then
    raise exception 'RLS exposed another user Task reminders.';
  end if;
  if (select count(*) from public.note_reminders) <> 0 then
    raise exception 'RLS exposed another user note reminders.';
  end if;

  begin
    insert into public.note_tasks (
      note_id,
      user_id,
      title,
      note_level_id,
      task_group_note_level_id
    )
    values (
      0,
      '00000000-0000-4000-8000-000000000101',
      'Forged',
      'forged-task',
      'forged-group'
    );
    raise exception 'Cross-owner Task insert unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- Even when history is already reviewed, pending Task verification must block
-- source deletion. An explicit zero-feature verification unlocks only this item.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

insert into public.notes (user_id, title, content)
values (
  '00000000-0000-4000-8000-000000000101',
  'No-feature fixture',
  'Body'
);

insert into public.evernote_migration_items (
  batch_id,
  user_id,
  source_item_key,
  target_note_id,
  status,
  history_status
)
select
  103,
  '00000000-0000-4000-8000-000000000101',
  'id:note-103',
  id,
  'verified',
  'reviewed_no_versions'
from public.notes
where title = 'No-feature fixture';

do $$
begin
  begin
    update public.evernote_migration_items
    set status = 'source_deleting'
    where batch_id = 103
      and source_item_key = 'id:note-103';
    raise exception 'Pending Task verification did not block source deletion.';
  exception
    when check_violation then
      null;
  end;
end
$$;

select public.evernote_verify_note_features(
  103,
  'id:note-103',
  jsonb_build_object(
    'task_count', true,
    'task_hashes', true,
    'task_reminder_hashes', true,
    'note_reminder_hash', true
  )
);

update public.evernote_migration_items
set status = 'source_deleting'
where batch_id = 103
  and source_item_key = 'id:note-103';

do $$
begin
  if (
    select task_status
    from public.evernote_migration_items
    where batch_id = 103
      and source_item_key = 'id:note-103'
  ) <> 'verified_no_features' then
    raise exception 'Explicit zero-feature verification was not preserved.';
  end if;
end
$$;

reset role;
