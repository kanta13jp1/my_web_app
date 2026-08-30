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

  if (
    select reminder_date
    from public.notes
    where title = 'Hierarchy fixture'
  ) is distinct from '2026-09-02T00:00:00Z'::timestamptz then
    raise exception 'Evernote note reminder was not bridged to the editor.';
  end if;
end
$$;

-- Imported source evidence remains immutable and cannot be deleted while the
-- corresponding Evernote source item still exists. Mutable Task fields remain
-- editable for native use.
do $$
declare
  v_task_id uuid;
begin
  select id into strict v_task_id
  from public.note_tasks
  where source_system = 'evernote';

  update public.note_tasks
  set status = 'completed'
  where id = v_task_id;

  if (
    select status
    from public.note_tasks
    where id = v_task_id
  ) <> 'completed' then
    raise exception 'Imported Task mutable fields could not be edited.';
  end if;

  begin
    update public.note_tasks
    set source_sha256 = repeat('a', 64)
    where id = v_task_id;
    raise exception 'Imported Task source hash was mutable.';
  exception
    when check_violation then
      null;
  end;

  begin
    delete from public.note_tasks
    where id = v_task_id;
    raise exception 'Imported Task was deleted before its source item.';
  exception
    when check_violation then
      null;
  end;
end
$$;

-- Native Task and reminder rows support normal authenticated CRUD.
do $$
declare
  v_note_id bigint;
  v_task_id uuid;
  v_reminder_id uuid;
begin
  select target_note_id into strict v_note_id
  from public.evernote_migration_items
  where batch_id = 101
    and source_item_key = 'id:note-101';

  insert into public.note_tasks (
    note_id,
    user_id,
    title,
    status,
    in_note,
    task_flag,
    sort_weight,
    note_level_id,
    task_group_note_level_id,
    source_system
  )
  values (
    v_note_id,
    '00000000-0000-4000-8000-000000000101',
    'Native CRUD fixture',
    'open',
    true,
    'false',
    '2',
    'native-task-101',
    'native-group-101',
    'native'
  )
  returning id into v_task_id;

  update public.note_tasks
  set status = 'completed'
  where id = v_task_id;

  insert into public.note_task_reminders (
    task_id,
    note_id,
    user_id,
    note_level_id,
    remind_at,
    status,
    source_system
  )
  values (
    v_task_id,
    v_note_id,
    '00000000-0000-4000-8000-000000000101',
    'native-reminder-101',
    '2026-09-03T00:00:00Z',
    'active',
    'native'
  )
  returning id into v_reminder_id;

  delete from public.note_task_reminders
  where id = v_reminder_id;
  delete from public.note_tasks
  where id = v_task_id;

  if exists (
    select 1
    from public.note_tasks
    where id = v_task_id
  ) then
    raise exception 'Native Task CRUD cleanup did not complete.';
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
