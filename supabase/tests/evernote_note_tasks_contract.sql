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
    select assignee_user_id
    from public.note_tasks
    where source_system = 'evernote'
  ) is distinct from '00000000-0000-4000-8000-000000000102'::uuid then
    raise exception 'Imported Task assignee was not linked by email.';
  end if;

  if (
    select source_assignee->>'email'
    from public.note_tasks
    where source_system = 'evernote'
  ) <> 'delegate@example.com' then
    raise exception 'Imported Task assignee evidence was not preserved.';
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

-- The owner receives the note reminder but not assignee-only Task delivery.
do $$
begin
  if (
    select count(*)
    from public.note_feature_notifications
  ) <> 1 then
    raise exception 'The owner inbox did not isolate the note reminder.';
  end if;
  if (
    select kind
    from public.note_feature_notifications
  ) <> 'note_reminder' then
    raise exception 'The owner inbox contained the wrong notification kind.';
  end if;

  begin
    update public.note_feature_notifications
    set read_at = clock_timestamp();
    raise exception 'Direct notification state mutation unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      null;
  end;
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
    update public.note_tasks
    set source_assignee = jsonb_build_object('email', 'changed@example.com')
    where id = v_task_id;
    raise exception 'Imported Task assignee evidence was mutable.';
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

-- The linked assignee can read only the assigned Task and its reminder,
-- and can change completion only through the narrow RPC.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
declare
  v_task_id uuid;
begin
  if (select count(*) from public.note_tasks) <> 1 then
    raise exception 'The assignee cannot read exactly the assigned Task.';
  end if;
  if (select count(*) from public.note_task_reminders) <> 1 then
    raise exception 'The assignee cannot read the assigned Task reminder.';
  end if;
  if (select count(*) from public.note_reminders) <> 0 then
    raise exception 'Task assignment exposed owner-only note reminders.';
  end if;

  if (
    select count(*)
    from public.note_feature_notifications
    where cancelled_at is null
      and dismissed_at is null
  ) <> 1 then
    raise exception 'Completed Task reminders were not paused.';
  end if;
  if (
    select count(*)
    from public.note_feature_notifications
    where kind = 'note_reminder'
  ) <> 0 then
    raise exception 'Task assignment exposed an owner note reminder notification.';
  end if;

  select id into strict v_task_id
  from public.note_tasks
  where source_system = 'evernote';

  perform public.note_task_set_completion(v_task_id, false);
  if (
    select status from public.note_tasks where id = v_task_id
  ) <> 'open' then
    raise exception 'The assignee could not reopen the assigned Task.';
  end if;

  if (
    select count(*)
    from public.note_feature_notifications
    where cancelled_at is null
      and dismissed_at is null
  ) <> 2 then
    raise exception 'Reopening did not restore the Task reminder.';
  end if;

  update public.note_tasks
  set title = 'Forged title'
  where id = v_task_id;
  if (
    select title from public.note_tasks where id = v_task_id
  ) = 'Forged title' then
    raise exception 'The assignee bypassed owner-only Task editing.';
  end if;

  begin
    perform public.note_task_assign(
      v_task_id,
      'other@example.com',
      'Other'
    );
    raise exception 'The assignee changed Task ownership.';
  exception
    when insufficient_privilege then
      null;
  end;

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

-- Read/dismiss state is recipient-only. Reassignment removes the old recipient's
-- derived notification rows together with Task visibility.
do $$
declare
  v_assignment_notification_id uuid;
  v_reminder_notification_id uuid;
begin
  select id into strict v_assignment_notification_id
  from public.note_feature_notifications
  where kind = 'task_assigned';

  perform public.note_feature_notification_mark_read(
    v_assignment_notification_id,
    true
  );
  if (
    select read_at
    from public.note_feature_notifications
    where id = v_assignment_notification_id
  ) is null then
    raise exception 'The assignee could not mark an assignment as read.';
  end if;

  select id into strict v_reminder_notification_id
  from public.note_feature_notifications
  where kind = 'task_reminder';

  perform public.note_feature_notification_dismiss(
    v_reminder_notification_id
  );
  if (
    select dismissed_at
    from public.note_feature_notifications
    where id = v_reminder_notification_id
  ) is null then
    raise exception 'The assignee could not dismiss a Task reminder.';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

select public.note_task_assign(
  (select id from public.note_tasks where source_system = 'evernote'),
  'owner@example.com',
  'Owner'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_tasks) <> 0 then
    raise exception 'Reassignment did not revoke old assignee Task visibility.';
  end if;
  if (select count(*) from public.note_feature_notifications) <> 0 then
    raise exception 'Reassignment retained old recipient notification content.';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

do $$
begin
  if (
    select count(*)
    from public.note_feature_notifications
    where cancelled_at is null
      and dismissed_at is null
  ) <> 3 then
    raise exception 'Owner reassignment inbox backfill was incomplete.';
  end if;
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
