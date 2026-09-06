-- Add owner/assignee scoped in-app notifications for note Tasks and reminders.
--
-- Notification rows are derived delivery state. They do not replace or weaken
-- immutable Evernote source hashes or the verified-before-deletion gate.
--
-- nocheck: time-relative
-- clock_timestamp() is used for delivery/read state, not CHECK constraints.

create table public.note_feature_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  note_id bigint not null,
  task_id uuid,
  task_reminder_id uuid,
  note_reminder_id uuid,
  kind text not null,
  title text not null,
  message text not null,
  notify_at timestamptz,
  read_at timestamptz,
  dismissed_at timestamptz,
  cancelled_at timestamptz,
  source_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_feature_notifications_note_owner_fkey
    foreign key (note_id, owner_user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint note_feature_notifications_task_owner_fkey
    foreign key (task_id, owner_user_id)
    references public.note_tasks (id, user_id)
    on delete cascade,
  constraint note_feature_notifications_task_reminder_fkey
    foreign key (task_reminder_id)
    references public.note_task_reminders (id)
    on delete cascade,
  constraint note_feature_notifications_note_reminder_fkey
    foreign key (note_reminder_id)
    references public.note_reminders (id)
    on delete cascade,
  constraint note_feature_notifications_kind_check
    check (kind in ('task_assigned', 'task_reminder', 'note_reminder')),
  constraint note_feature_notifications_shape_check
    check (
      (
        kind = 'task_assigned'
        and task_id is not null
        and task_reminder_id is null
        and note_reminder_id is null
      )
      or (
        kind = 'task_reminder'
        and task_id is not null
        and task_reminder_id is not null
        and note_reminder_id is null
        and notify_at is not null
      )
      or (
        kind = 'note_reminder'
        and task_id is null
        and task_reminder_id is null
        and note_reminder_id is not null
        and notify_at is not null
      )
    ),
  constraint note_feature_notifications_source_unique
    unique (user_id, kind, source_key)
);

create index note_feature_notifications_user_inbox_idx
  on public.note_feature_notifications (
    user_id,
    dismissed_at,
    cancelled_at,
    read_at,
    notify_at,
    created_at
  );

create index note_feature_notifications_task_idx
  on public.note_feature_notifications (task_id)
  where task_id is not null;

alter table public.note_feature_notifications enable row level security;

create policy note_feature_notifications_select_recipient
  on public.note_feature_notifications
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_feature_notifications
  from public, anon, authenticated, service_role;
grant select on table public.note_feature_notifications to authenticated;
grant all on table public.note_feature_notifications to service_role;

create or replace function
  evernote_migration_private.sync_note_task_notifications(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.note_tasks%rowtype;
  v_recipient uuid;
  v_reminder public.note_task_reminders%rowtype;
begin
  select *
  into v_task
  from public.note_tasks
  where id = p_task_id;

  if not found then
    return;
  end if;

  v_recipient := coalesce(v_task.assignee_user_id, v_task.user_id);

  delete from public.note_feature_notifications as notification
  where notification.task_id = v_task.id
    and (
      (
        notification.kind = 'task_assigned'
        and (
          v_task.assignee_user_id is null
          or notification.user_id <> v_task.assignee_user_id
        )
      )
      or (
        notification.kind = 'task_reminder'
        and notification.user_id <> v_recipient
      )
    );

  update public.note_feature_notifications as notification
  set
    cancelled_at = coalesce(notification.cancelled_at, clock_timestamp()),
    updated_at = clock_timestamp()
  where notification.task_id = v_task.id
    and notification.kind = 'task_reminder'
    and notification.user_id = v_recipient
    and (
      v_task.status = 'completed'
      or not exists (
        select 1
        from public.note_task_reminders as reminder
        where reminder.id = notification.task_reminder_id
          and reminder.task_id = v_task.id
          and reminder.user_id = v_task.user_id
          and reminder.remind_at is not null
          and reminder.status is distinct from 'muted'
      )
    );

  if v_task.assignee_user_id is not null then
    insert into public.note_feature_notifications (
      user_id,
      owner_user_id,
      note_id,
      task_id,
      kind,
      title,
      message,
      notify_at,
      source_key
    )
    values (
      v_task.assignee_user_id,
      v_task.user_id,
      v_task.note_id,
      v_task.id,
      'task_assigned',
      'タスクが割り当てられました',
      v_task.title,
      clock_timestamp(),
      'task:' || v_task.id::text || ':assignment'
    )
    on conflict (user_id, kind, source_key)
    do update set
      title = excluded.title,
      message = excluded.message,
      notify_at = excluded.notify_at,
      cancelled_at = null,
      updated_at = clock_timestamp();
  end if;

  if v_task.status = 'completed' then
    return;
  end if;

  for v_reminder in
    select *
    from public.note_task_reminders
    where task_id = v_task.id
      and user_id = v_task.user_id
      and remind_at is not null
      and status is distinct from 'muted'
  loop
    insert into public.note_feature_notifications (
      user_id,
      owner_user_id,
      note_id,
      task_id,
      task_reminder_id,
      kind,
      title,
      message,
      notify_at,
      source_key
    )
    values (
      v_recipient,
      v_task.user_id,
      v_task.note_id,
      v_task.id,
      v_reminder.id,
      'task_reminder',
      'タスクリマインダー',
      v_task.title,
      v_reminder.remind_at,
      'task-reminder:' || v_reminder.id::text
    )
    on conflict (user_id, kind, source_key)
    do update set
      title = excluded.title,
      message = excluded.message,
      notify_at = excluded.notify_at,
      cancelled_at = null,
      updated_at = clock_timestamp();
  end loop;
end
$$;

revoke all on function
  evernote_migration_private.sync_note_task_notifications(uuid)
  from public, anon, authenticated, service_role;

create or replace function
  evernote_migration_private.sync_note_reminder_notification(
    p_note_reminder_id uuid
  )
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reminder public.note_reminders%rowtype;
  v_note_title text;
begin
  select *
  into v_reminder
  from public.note_reminders
  where id = p_note_reminder_id;

  if not found then
    return;
  end if;

  if v_reminder.remind_at is null
     or v_reminder.completed_at is not null then
    update public.note_feature_notifications
    set
      cancelled_at = coalesce(cancelled_at, clock_timestamp()),
      updated_at = clock_timestamp()
    where note_reminder_id = v_reminder.id;
    return;
  end if;

  select title
  into v_note_title
  from public.notes
  where id = v_reminder.note_id
    and user_id = v_reminder.user_id;

  insert into public.note_feature_notifications (
    user_id,
    owner_user_id,
    note_id,
    note_reminder_id,
    kind,
    title,
    message,
    notify_at,
    source_key
  )
  values (
    v_reminder.user_id,
    v_reminder.user_id,
    v_reminder.note_id,
    v_reminder.id,
    'note_reminder',
    'ノートリマインダー',
    coalesce(v_note_title, 'ノート #' || v_reminder.note_id::text),
    v_reminder.remind_at,
    'note-reminder:' || v_reminder.id::text
  )
  on conflict (user_id, kind, source_key)
  do update set
    title = excluded.title,
    message = excluded.message,
    notify_at = excluded.notify_at,
    dismissed_at = null,
    updated_at = clock_timestamp();
end
$$;

revoke all on function
  evernote_migration_private.sync_note_reminder_notification(uuid)
  from public, anon, authenticated, service_role;

create or replace function
  evernote_migration_private.note_task_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform evernote_migration_private.sync_note_task_notifications(
    case when tg_op = 'DELETE' then old.id else new.id end
  );
  return case when tg_op = 'DELETE' then old else new end;
end
$$;

revoke all on function
  evernote_migration_private.note_task_notification_trigger()
  from public, anon, authenticated, service_role;

create or replace function
  evernote_migration_private.note_task_reminder_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform evernote_migration_private.sync_note_task_notifications(old.task_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.task_id is distinct from new.task_id then
    perform evernote_migration_private.sync_note_task_notifications(old.task_id);
  end if;
  perform evernote_migration_private.sync_note_task_notifications(new.task_id);
  return new;
end
$$;

revoke all on function
  evernote_migration_private.note_task_reminder_notification_trigger()
  from public, anon, authenticated, service_role;

create or replace function
  evernote_migration_private.note_reminder_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform evernote_migration_private.sync_note_reminder_notification(
    case when tg_op = 'DELETE' then old.id else new.id end
  );
  return case when tg_op = 'DELETE' then old else new end;
end
$$;

revoke all on function
  evernote_migration_private.note_reminder_notification_trigger()
  from public, anon, authenticated, service_role;

create trigger sync_note_task_notifications
  after insert or update of assignee_user_id, status, title
  on public.note_tasks
  for each row
  execute function
    evernote_migration_private.note_task_notification_trigger();

create trigger sync_note_task_reminder_notifications
  after insert or update or delete
  on public.note_task_reminders
  for each row
  execute function
    evernote_migration_private.note_task_reminder_notification_trigger();

create trigger sync_note_reminder_notifications
  after insert or update of remind_at, completed_at or delete
  on public.note_reminders
  for each row
  execute function
    evernote_migration_private.note_reminder_notification_trigger();

do $$
declare
  v_task_id uuid;
  v_note_reminder_id uuid;
begin
  for v_task_id in select id from public.note_tasks loop
    perform evernote_migration_private.sync_note_task_notifications(v_task_id);
  end loop;
  for v_note_reminder_id in select id from public.note_reminders loop
    perform evernote_migration_private.sync_note_reminder_notification(
      v_note_reminder_id
    );
  end loop;
end
$$;

create or replace function public.note_feature_notification_mark_read(
  p_notification_id uuid,
  p_read boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_read_at timestamptz;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  update public.note_feature_notifications
  set
    read_at = case when p_read then clock_timestamp() else null end,
    updated_at = clock_timestamp()
  where id = p_notification_id
    and user_id = v_user_id
  returning read_at into v_read_at;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The notification does not belong to this user.';
  end if;

  return jsonb_build_object(
    'notification_id', p_notification_id,
    'read', v_read_at is not null
  );
end
$$;

create or replace function public.note_feature_notification_dismiss(
  p_notification_id uuid
)
returns jsonb
language plpgsql
security definer
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

  update public.note_feature_notifications
  set
    dismissed_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where id = p_notification_id
    and user_id = v_user_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The notification does not belong to this user.';
  end if;

  return jsonb_build_object(
    'notification_id', p_notification_id,
    'dismissed', true
  );
end
$$;

revoke all on function
  public.note_feature_notification_mark_read(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all on function
  public.note_feature_notification_dismiss(uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.note_feature_notification_mark_read(uuid, boolean)
  to authenticated;
grant execute on function
  public.note_feature_notification_dismiss(uuid)
  to authenticated;

comment on table public.note_feature_notifications is
  'Derived recipient inbox for Task assignment and note/Task reminders.';
comment on function
  public.note_feature_notification_mark_read(uuid, boolean) is
  'Recipient-only read-state transition for a derived note notification.';
comment on function
  public.note_feature_notification_dismiss(uuid) is
  'Recipient-only dismissal for a derived note notification.';
