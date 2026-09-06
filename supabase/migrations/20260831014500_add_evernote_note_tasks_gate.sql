-- Promote Evernote Tasks and reminders into owner-scoped native note data.
--
-- Structured Task payloads are committed in the same RPC transaction as the
-- imported note and hierarchy. Source hashes are compared again before any
-- Evernote source-deletion state is allowed.
--
-- nocheck: time-relative
-- All state transitions are owner-scoped and covered by the disposable
-- PostgreSQL contract with fixed fixture timestamps.

create table public.note_tasks (
  id uuid primary key default gen_random_uuid(),
  note_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  status text not null default 'open',
  in_note boolean not null default true,
  task_flag text not null default 'false',
  sort_weight text not null default '0',
  note_level_id text not null,
  task_group_note_level_id text not null,
  due_at timestamptz,
  due_date_ui_option text,
  time_zone text,
  recurrence text,
  repeat_after_completion boolean,
  status_updated_at timestamptz,
  creator text,
  last_editor text,
  source_created_at timestamptz,
  source_updated_at timestamptz,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_tasks_id_user_key unique (id, user_id),
  constraint note_tasks_note_owner_fkey
    foreign key (note_id, user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint note_tasks_title_check
    check (char_length(btrim(title)) between 1 and 4096),
  constraint note_tasks_status_check
    check (status in ('open', 'completed')),
  constraint note_tasks_due_ui_check
    check (
      due_date_ui_option is null
      or due_date_ui_option in ('date_time', 'date_only')
    ),
  constraint note_tasks_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_tasks_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    ),
  constraint note_tasks_source_key_unique
    unique (user_id, note_id, source_system, source_key)
);

create index note_tasks_user_note_status_idx
  on public.note_tasks (user_id, note_id, status);

create index note_tasks_user_due_idx
  on public.note_tasks (user_id, due_at)
  where due_at is not null and status = 'open';

alter table public.note_tasks enable row level security;

create policy note_tasks_select_owner
  on public.note_tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy note_tasks_insert_owner
  on public.note_tasks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy note_tasks_update_owner
  on public.note_tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy note_tasks_delete_owner
  on public.note_tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_tasks
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.note_tasks
  to authenticated;
grant all on table public.note_tasks to service_role;

create table public.note_task_reminders (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null,
  note_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  note_level_id text not null,
  remind_at timestamptz,
  reminder_date_ui_option text,
  time_zone text,
  due_date_offset bigint,
  status text,
  source_created_at timestamptz,
  source_updated_at timestamptz,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_task_reminders_task_owner_fkey
    foreign key (task_id, user_id)
    references public.note_tasks (id, user_id)
    on delete cascade,
  constraint note_task_reminders_note_owner_fkey
    foreign key (note_id, user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint note_task_reminders_ui_check
    check (
      reminder_date_ui_option is null
      or reminder_date_ui_option in (
        'date_time',
        'date_only',
        'relative_to_due'
      )
    ),
  constraint note_task_reminders_status_check
    check (status is null or status in ('active', 'muted')),
  constraint note_task_reminders_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_task_reminders_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    ),
  constraint note_task_reminders_source_key_unique
    unique (user_id, task_id, source_system, source_key)
);

create index note_task_reminders_user_note_idx
  on public.note_task_reminders (user_id, note_id);

create index note_task_reminders_task_idx
  on public.note_task_reminders (task_id);

create index note_task_reminders_user_due_idx
  on public.note_task_reminders (user_id, remind_at)
  where remind_at is not null and status is distinct from 'muted';

alter table public.note_task_reminders enable row level security;

create policy note_task_reminders_select_owner
  on public.note_task_reminders
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy note_task_reminders_insert_owner
  on public.note_task_reminders
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy note_task_reminders_update_owner
  on public.note_task_reminders
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy note_task_reminders_delete_owner
  on public.note_task_reminders
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_task_reminders
  from public, anon, authenticated, service_role;
grant select, insert, update, delete
  on table public.note_task_reminders to authenticated;
grant all on table public.note_task_reminders to service_role;

create table public.note_reminders (
  id uuid primary key default gen_random_uuid(),
  note_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  order_weight bigint,
  remind_at timestamptz,
  completed_at timestamptz,
  source_system text not null default 'native',
  source_key text,
  source_sha256 text,
  source_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_reminders_note_owner_fkey
    foreign key (note_id, user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint note_reminders_note_unique unique (user_id, note_id),
  constraint note_reminders_order_check
    check (order_weight is null or order_weight > 0),
  constraint note_reminders_value_check
    check (
      order_weight is not null
      or remind_at is not null
      or completed_at is not null
    ),
  constraint note_reminders_source_system_check
    check (source_system in ('native', 'evernote')),
  constraint note_reminders_evernote_source_check
    check (
      source_system <> 'evernote'
      or (
        source_key is not null
        and source_sha256 ~ '^[0-9a-f]{64}$'
      )
    )
);

create index note_reminders_user_due_idx
  on public.note_reminders (user_id, remind_at)
  where remind_at is not null and completed_at is null;

alter table public.note_reminders enable row level security;

create policy note_reminders_select_owner
  on public.note_reminders
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy note_reminders_insert_owner
  on public.note_reminders
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy note_reminders_update_owner
  on public.note_reminders
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy note_reminders_delete_owner
  on public.note_reminders
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_reminders
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.note_reminders
  to authenticated;
grant all on table public.note_reminders to service_role;

alter table public.evernote_migration_items
  add column if not exists task_status text not null default 'pending',
  add column if not exists source_task_count bigint not null default 0,
  add column if not exists imported_task_count bigint not null default 0,
  add column if not exists verified_task_count bigint not null default 0,
  add column if not exists source_task_reminder_count bigint not null default 0,
  add column if not exists imported_task_reminder_count bigint not null default 0,
  add column if not exists verified_task_reminder_count bigint not null default 0,
  add column if not exists source_note_reminder_present boolean not null default false,
  add column if not exists note_reminder_verified boolean not null default false,
  add column if not exists task_verified_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'evernote_migration_items_task_status_check'
      and conrelid = 'public.evernote_migration_items'::regclass
  ) then
    alter table public.evernote_migration_items
      add constraint evernote_migration_items_task_status_check
      check (
        task_status in (
          'pending',
          'imported',
          'verified',
          'verified_no_features'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'evernote_migration_items_task_counts_check'
      and conrelid = 'public.evernote_migration_items'::regclass
  ) then
    alter table public.evernote_migration_items
      add constraint evernote_migration_items_task_counts_check
      check (
        source_task_count >= 0
        and imported_task_count between 0 and source_task_count
        and verified_task_count between 0 and imported_task_count
        and source_task_reminder_count >= 0
        and imported_task_reminder_count
          between 0 and source_task_reminder_count
        and verified_task_reminder_count
          between 0 and imported_task_reminder_count
        and (
          task_status <> 'verified_no_features'
          or (
            source_task_count = 0
            and imported_task_count = 0
            and verified_task_count = 0
            and source_task_reminder_count = 0
            and imported_task_reminder_count = 0
            and verified_task_reminder_count = 0
            and source_note_reminder_present is false
            and note_reminder_verified is false
          )
        )
        and (
          task_status <> 'verified'
          or (
            verified_task_count = source_task_count
            and verified_task_reminder_count =
              source_task_reminder_count
            and note_reminder_verified =
              source_note_reminder_present
          )
        )
      );
  end if;
end
$$;

create or replace function
  evernote_migration_private.enforce_tasks_before_source_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('source_deleting', 'source_deleted')
     and new.task_status not in ('verified', 'verified_no_features') then
    raise exception using
      errcode = '23514',
      message =
        'Evernote Tasks and reminders must be verified before source deletion.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.enforce_tasks_before_source_deletion()
  from public, anon, authenticated, service_role;

drop trigger if exists enforce_evernote_tasks_before_source_deletion
  on public.evernote_migration_items;
create trigger enforce_evernote_tasks_before_source_deletion
  before insert or update of status, task_status
  on public.evernote_migration_items
  for each row
  execute function
    evernote_migration_private.enforce_tasks_before_source_deletion();

create or replace function
  evernote_migration_private.protect_imported_note_feature_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_deleted boolean;
begin
  if old.source_system <> 'evernote' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE' then
    select exists (
      select 1
      from public.evernote_migration_items
      where user_id = old.user_id
        and target_note_id = old.note_id
        and status = 'source_deleted'
    )
    into v_source_deleted;

    if not v_source_deleted then
      raise exception using
        errcode = '23514',
        message =
          'Imported Evernote Task evidence cannot be deleted before the source.';
    end if;
    return old;
  end if;

  if new.user_id is distinct from old.user_id
     or new.note_id is distinct from old.note_id
     or new.source_system is distinct from old.source_system
     or new.source_key is distinct from old.source_key
     or new.source_sha256 is distinct from old.source_sha256
     or new.source_metadata is distinct from old.source_metadata then
    raise exception using
      errcode = '23514',
      message = 'Imported Evernote Task source evidence is immutable.';
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.protect_imported_note_feature_source()
  from public, anon, authenticated, service_role;

create trigger protect_imported_note_task_source
  before update or delete on public.note_tasks
  for each row
  execute function
    evernote_migration_private.protect_imported_note_feature_source();

create trigger protect_imported_note_task_reminder_source
  before update or delete on public.note_task_reminders
  for each row
  execute function
    evernote_migration_private.protect_imported_note_feature_source();

create trigger protect_imported_note_reminder_source
  before update or delete on public.note_reminders
  for each row
  execute function
    evernote_migration_private.protect_imported_note_feature_source();

create or replace function public.evernote_commit_note_with_features(
  p_batch_id bigint,
  p_source_item_key text,
  p_title text,
  p_content text,
  p_source_created_at timestamptz,
  p_source_updated_at timestamptz,
  p_tags text[],
  p_source_enml text,
  p_source_metadata jsonb,
  p_tasks jsonb,
  p_note_reminder jsonb,
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
  v_note_id bigint;
  v_source_task_count bigint;
  v_source_task_reminder_count bigint;
  v_imported_task_count bigint;
  v_imported_task_reminder_count bigint;
  v_note_reminder_imported boolean;
  v_no_features boolean;
  v_task_status text;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_tasks is null or jsonb_typeof(p_tasks) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'Evernote Tasks must be a JSON array.';
  end if;
  if p_note_reminder is not null
     and jsonb_typeof(p_note_reminder) <> 'object' then
    raise exception using
      errcode = '22023',
      message = 'The Evernote note reminder must be a JSON object or null.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_tasks) as task(value)
    where jsonb_typeof(task.value) <> 'object'
      or coalesce(btrim(task.value->>'title'), '') = ''
      or coalesce(task.value->>'status', '') not in ('open', 'completed')
      or jsonb_typeof(task.value->'in_note') is distinct from 'boolean'
      or coalesce(task.value->>'task_flag', '') = ''
      or coalesce(task.value->>'sort_weight', '') = ''
      or coalesce(task.value->>'note_level_id', '') = ''
      or coalesce(task.value->>'task_group_note_level_id', '') = ''
      or coalesce(task.value->>'created_at', '') = ''
      or coalesce(task.value->>'updated_at', '') = ''
      or coalesce(task.value->>'source_sha256', '')
        !~ '^[0-9a-f]{64}$'
      or jsonb_typeof(task.value->'reminders') is distinct from 'array'
      or (
        task.value->>'due_date_ui_option' is not null
        and task.value->>'due_date_ui_option'
          not in ('date_time', 'date_only')
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'An Evernote Task payload is invalid.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_tasks) as task(value)
    cross join lateral jsonb_array_elements(
      task.value->'reminders'
    ) as reminder(value)
    where jsonb_typeof(reminder.value) <> 'object'
      or coalesce(reminder.value->>'note_level_id', '') = ''
      or coalesce(reminder.value->>'created_at', '') = ''
      or coalesce(reminder.value->>'updated_at', '') = ''
      or coalesce(reminder.value->>'source_sha256', '')
        !~ '^[0-9a-f]{64}$'
      or (
        reminder.value->>'reminder_date_ui_option' is not null
        and reminder.value->>'reminder_date_ui_option'
          not in ('date_time', 'date_only', 'relative_to_due')
      )
      or (
        reminder.value->>'status' is not null
        and reminder.value->>'status' not in ('active', 'muted')
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'An Evernote Task reminder payload is invalid.';
  end if;

  if p_note_reminder is not null
     and (
       coalesce(p_note_reminder->>'source_sha256', '')
         !~ '^[0-9a-f]{64}$'
       or (
         p_note_reminder->>'order' is null
         and p_note_reminder->>'reminder_at' is null
         and p_note_reminder->>'completed_at' is null
       )
     ) then
    raise exception using
      errcode = '22023',
      message = 'The Evernote note reminder payload is invalid.';
  end if;

  v_result := public.evernote_commit_note_with_hierarchy(
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
    due_at,
    due_date_ui_option,
    time_zone,
    recurrence,
    repeat_after_completion,
    status_updated_at,
    creator,
    last_editor,
    source_created_at,
    source_updated_at,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select
    v_note_id,
    v_user_id,
    task.value->>'title',
    task.value->>'status',
    (task.value->>'in_note')::boolean,
    task.value->>'task_flag',
    task.value->>'sort_weight',
    task.value->>'note_level_id',
    task.value->>'task_group_note_level_id',
    nullif(task.value->>'due_at', '')::timestamptz,
    task.value->>'due_date_ui_option',
    task.value->>'time_zone',
    task.value->>'recurrence',
    nullif(task.value->>'repeat_after_completion', '')::boolean,
    nullif(task.value->>'status_updated_at', '')::timestamptz,
    task.value->>'creator',
    task.value->>'last_editor',
    (task.value->>'created_at')::timestamptz,
    (task.value->>'updated_at')::timestamptz,
    'evernote',
    task.value->>'note_level_id',
    task.value->>'source_sha256',
    task.value
  from jsonb_array_elements(p_tasks) as task(value)
  on conflict (user_id, note_id, source_system, source_key)
  do update set
    title = excluded.title,
    status = excluded.status,
    in_note = excluded.in_note,
    task_flag = excluded.task_flag,
    sort_weight = excluded.sort_weight,
    note_level_id = excluded.note_level_id,
    task_group_note_level_id = excluded.task_group_note_level_id,
    due_at = excluded.due_at,
    due_date_ui_option = excluded.due_date_ui_option,
    time_zone = excluded.time_zone,
    recurrence = excluded.recurrence,
    repeat_after_completion = excluded.repeat_after_completion,
    status_updated_at = excluded.status_updated_at,
    creator = excluded.creator,
    last_editor = excluded.last_editor,
    source_created_at = excluded.source_created_at,
    source_updated_at = excluded.source_updated_at,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata,
    updated_at = clock_timestamp();

  insert into public.note_task_reminders (
    task_id,
    note_id,
    user_id,
    note_level_id,
    remind_at,
    reminder_date_ui_option,
    time_zone,
    due_date_offset,
    status,
    source_created_at,
    source_updated_at,
    source_system,
    source_key,
    source_sha256,
    source_metadata
  )
  select
    stored_task.id,
    v_note_id,
    v_user_id,
    reminder.value->>'note_level_id',
    nullif(reminder.value->>'reminder_at', '')::timestamptz,
    reminder.value->>'reminder_date_ui_option',
    reminder.value->>'time_zone',
    nullif(reminder.value->>'due_date_offset', '')::bigint,
    reminder.value->>'status',
    (reminder.value->>'created_at')::timestamptz,
    (reminder.value->>'updated_at')::timestamptz,
    'evernote',
    reminder.value->>'note_level_id',
    reminder.value->>'source_sha256',
    reminder.value
  from jsonb_array_elements(p_tasks) as task(value)
  join public.note_tasks as stored_task
    on stored_task.user_id = v_user_id
   and stored_task.note_id = v_note_id
   and stored_task.source_system = 'evernote'
   and stored_task.source_key = task.value->>'note_level_id'
  cross join lateral jsonb_array_elements(
    task.value->'reminders'
  ) as reminder(value)
  on conflict (user_id, task_id, source_system, source_key)
  do update set
    note_id = excluded.note_id,
    note_level_id = excluded.note_level_id,
    remind_at = excluded.remind_at,
    reminder_date_ui_option = excluded.reminder_date_ui_option,
    time_zone = excluded.time_zone,
    due_date_offset = excluded.due_date_offset,
    status = excluded.status,
    source_created_at = excluded.source_created_at,
    source_updated_at = excluded.source_updated_at,
    source_sha256 = excluded.source_sha256,
    source_metadata = excluded.source_metadata,
    updated_at = clock_timestamp();

  if p_note_reminder is not null then
    insert into public.note_reminders (
      note_id,
      user_id,
      order_weight,
      remind_at,
      completed_at,
      source_system,
      source_key,
      source_sha256,
      source_metadata
    )
    values (
      v_note_id,
      v_user_id,
      nullif(p_note_reminder->>'order', '')::bigint,
      nullif(p_note_reminder->>'reminder_at', '')::timestamptz,
      nullif(p_note_reminder->>'completed_at', '')::timestamptz,
      'evernote',
      p_source_item_key,
      p_note_reminder->>'source_sha256',
      p_note_reminder
    )
    on conflict (user_id, note_id)
    do update set
      order_weight = excluded.order_weight,
      remind_at = excluded.remind_at,
      completed_at = excluded.completed_at,
      source_system = excluded.source_system,
      source_key = excluded.source_key,
      source_sha256 = excluded.source_sha256,
      source_metadata = excluded.source_metadata,
      updated_at = clock_timestamp();
  end if;

  update public.notes
  set reminder_date = case
    when p_note_reminder is not null
      and p_note_reminder->>'completed_at' is null
    then nullif(p_note_reminder->>'reminder_at', '')::timestamptz
    else null
  end
  where id = v_note_id
    and user_id = v_user_id;

  v_source_task_count := jsonb_array_length(p_tasks);
  select count(*)
  into v_source_task_reminder_count
  from jsonb_array_elements(p_tasks) as task(value)
  cross join lateral jsonb_array_elements(
    task.value->'reminders'
  ) as reminder(value);

  select count(*)
  into v_imported_task_count
  from public.note_tasks
  where user_id = v_user_id
    and note_id = v_note_id
    and source_system = 'evernote';

  select count(*)
  into v_imported_task_reminder_count
  from public.note_task_reminders
  where user_id = v_user_id
    and note_id = v_note_id
    and source_system = 'evernote';

  select exists (
    select 1
    from public.note_reminders
    where user_id = v_user_id
      and note_id = v_note_id
      and source_system = 'evernote'
  )
  into v_note_reminder_imported;

  if v_imported_task_count <> v_source_task_count
     or v_imported_task_reminder_count <>
       v_source_task_reminder_count
     or v_note_reminder_imported <> (p_note_reminder is not null) then
    raise exception using
      errcode = '23514',
      message = 'Evernote Task or reminder commit is incomplete.';
  end if;

  v_no_features :=
    v_source_task_count = 0
    and v_source_task_reminder_count = 0
    and p_note_reminder is null;

  update public.evernote_migration_items
  set
    source_metadata = coalesce(source_metadata, '{}'::jsonb)
      || jsonb_build_object(
        'tasks',
        p_tasks,
        'note_reminder',
        p_note_reminder
      ),
    source_task_count = v_source_task_count,
    imported_task_count = v_imported_task_count,
    source_task_reminder_count = v_source_task_reminder_count,
    imported_task_reminder_count = v_imported_task_reminder_count,
    source_note_reminder_present = p_note_reminder is not null,
    task_status = case
      when v_no_features then 'verified_no_features'
      when task_status = 'verified'
        and verified_task_count = v_source_task_count
        and verified_task_reminder_count =
          v_source_task_reminder_count
        and note_reminder_verified = (p_note_reminder is not null)
      then 'verified'
      else 'imported'
    end,
    verified_task_count = case
      when v_no_features then 0
      when task_status = 'verified'
        and verified_task_count = v_source_task_count
      then verified_task_count
      else 0
    end,
    verified_task_reminder_count = case
      when v_no_features then 0
      when task_status = 'verified'
        and verified_task_reminder_count =
          v_source_task_reminder_count
      then verified_task_reminder_count
      else 0
    end,
    note_reminder_verified = case
      when v_no_features then false
      when task_status = 'verified'
        and note_reminder_verified = (p_note_reminder is not null)
      then note_reminder_verified
      else false
    end,
    task_verified_at = case
      when v_no_features then coalesce(task_verified_at, clock_timestamp())
      when task_status = 'verified' then task_verified_at
      else null
    end,
    updated_at = clock_timestamp()
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key
  returning task_status into v_task_status;

  if v_task_status is null then
    raise exception using
      errcode = 'P0002',
      message = 'The Evernote migration item was not found.';
  end if;

  return v_result || jsonb_build_object(
    'task_status', v_task_status,
    'task_count', v_imported_task_count,
    'task_reminder_count', v_imported_task_reminder_count,
    'note_reminder', v_note_reminder_imported
  );
end
$$;

create or replace function public.evernote_verify_note_features(
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
  v_item public.evernote_migration_items%rowtype;
  v_tasks jsonb;
  v_note_reminder jsonb;
  v_expected_task_hashes text[];
  v_actual_task_hashes text[];
  v_expected_reminder_hashes text[];
  v_actual_reminder_hashes text[];
  v_expected_note_reminder_hash text;
  v_actual_note_reminder_hash text;
  v_task_count bigint;
  v_task_reminder_count bigint;
  v_no_features boolean;
  v_task_status text;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_verification_checks is null
     or jsonb_typeof(p_verification_checks) <> 'object'
     or coalesce(
       (p_verification_checks->>'task_count')::boolean,
       false
     ) is not true
     or coalesce(
       (p_verification_checks->>'task_hashes')::boolean,
       false
     ) is not true
     or coalesce(
       (p_verification_checks->>'task_reminder_hashes')::boolean,
       false
     ) is not true
     or coalesce(
       (p_verification_checks->>'note_reminder_hash')::boolean,
       false
     ) is not true then
    raise exception using
      errcode = '23514',
      message = 'All Evernote Task verification checks must pass.';
  end if;

  select *
  into v_item
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key
  for update;

  if not found or v_item.target_note_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The imported Evernote note was not found.';
  end if;

  v_tasks := coalesce(v_item.source_metadata->'tasks', '[]'::jsonb);
  v_note_reminder := nullif(
    v_item.source_metadata->'note_reminder',
    'null'::jsonb
  );
  if jsonb_typeof(v_tasks) <> 'array' then
    raise exception using
      errcode = '23514',
      message = 'Stored Evernote Task metadata is invalid.';
  end if;

  select coalesce(
    array_agg(task.value->>'source_sha256'
      order by task.value->>'source_sha256'),
    '{}'::text[]
  )
  into v_expected_task_hashes
  from jsonb_array_elements(v_tasks) as task(value);

  select coalesce(
    array_agg(source_sha256 order by source_sha256),
    '{}'::text[]
  ), count(*)
  into v_actual_task_hashes, v_task_count
  from public.note_tasks
  where user_id = v_user_id
    and note_id = v_item.target_note_id
    and source_system = 'evernote';

  select coalesce(
    array_agg(reminder.value->>'source_sha256'
      order by reminder.value->>'source_sha256'),
    '{}'::text[]
  )
  into v_expected_reminder_hashes
  from jsonb_array_elements(v_tasks) as task(value)
  cross join lateral jsonb_array_elements(
    task.value->'reminders'
  ) as reminder(value);

  select coalesce(
    array_agg(source_sha256 order by source_sha256),
    '{}'::text[]
  ), count(*)
  into v_actual_reminder_hashes, v_task_reminder_count
  from public.note_task_reminders
  where user_id = v_user_id
    and note_id = v_item.target_note_id
    and source_system = 'evernote';

  v_expected_note_reminder_hash :=
    v_note_reminder->>'source_sha256';
  select source_sha256
  into v_actual_note_reminder_hash
  from public.note_reminders
  where user_id = v_user_id
    and note_id = v_item.target_note_id
    and source_system = 'evernote';

  if v_task_count <> v_item.source_task_count
     or v_task_reminder_count <>
       v_item.source_task_reminder_count
     or v_actual_task_hashes is distinct from
       v_expected_task_hashes
     or v_actual_reminder_hashes is distinct from
       v_expected_reminder_hashes
     or v_actual_note_reminder_hash is distinct from
       v_expected_note_reminder_hash then
    raise exception using
      errcode = '23514',
      message = 'Stored Evernote Tasks or reminders do not match source hashes.';
  end if;

  v_no_features :=
    v_item.source_task_count = 0
    and v_item.source_task_reminder_count = 0
    and v_note_reminder is null;
  v_task_status := case
    when v_no_features then 'verified_no_features'
    else 'verified'
  end;

  update public.evernote_migration_items
  set
    verified_task_count = source_task_count,
    verified_task_reminder_count = source_task_reminder_count,
    note_reminder_verified = source_note_reminder_present,
    task_status = v_task_status,
    task_verified_at = coalesce(task_verified_at, clock_timestamp()),
    updated_at = clock_timestamp()
  where id = v_item.id;

  return jsonb_build_object(
    'note_id', v_item.target_note_id,
    'task_status', v_task_status,
    'task_count', v_task_count,
    'task_reminder_count', v_task_reminder_count,
    'note_reminder', v_note_reminder is not null
  );
end
$$;

create or replace function public.evernote_verify_note_with_features(
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
  v_note_result jsonb;
  v_feature_result jsonb;
begin
  v_note_result := public.evernote_verify_note_with_hierarchy(
    p_batch_id,
    p_source_item_key,
    p_verification_checks
  );
  v_feature_result := public.evernote_verify_note_features(
    p_batch_id,
    p_source_item_key,
    p_verification_checks
  );
  return v_note_result || jsonb_build_object(
    'features',
    v_feature_result
  );
end
$$;

revoke all on function public.evernote_commit_note_with_features(
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
  jsonb,
  jsonb,
  text,
  text
) from public, anon, authenticated, service_role;

revoke all on function public.evernote_verify_note_features(
  bigint,
  text,
  jsonb
) from public, anon, authenticated, service_role;

revoke all on function public.evernote_verify_note_with_features(
  bigint,
  text,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.evernote_commit_note_with_features(
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
  jsonb,
  jsonb,
  text,
  text
) to authenticated;

grant execute on function public.evernote_verify_note_features(
  bigint,
  text,
  jsonb
) to authenticated;

grant execute on function public.evernote_verify_note_with_features(
  bigint,
  text,
  jsonb
) to authenticated;

comment on table public.note_tasks is
  'Owner-scoped native note Tasks, including lossless Evernote Task imports.';
comment on table public.note_task_reminders is
  'Owner-scoped reminders attached to native note Tasks.';
comment on table public.note_reminders is
  'Owner-scoped note-level reminders.';
comment on function public.evernote_commit_note_with_features(
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
  jsonb,
  jsonb,
  text,
  text
) is
  'Atomically commits an Evernote note, hierarchy, Tasks, and reminders.';
comment on function public.evernote_verify_note_features(
  bigint,
  text,
  jsonb
) is
  'Verifies native Task/reminder counts and source hashes before deletion.';
