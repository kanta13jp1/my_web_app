-- Add single-assignee Task semantics without sharing the source note.
--
-- Imported identity evidence stays immutable, while the operational assignee
-- can be linked to a local account by exact email. Assignees can read the Task
-- and its Task reminders, but can only change completion through a narrow RPC.
--
-- nocheck: time-relative
-- clock_timestamp() is used only for mutable audit timestamps, never inside
-- a CHECK constraint.
-- nocheck: auth-users-email
-- The owner-initiated lookup returns only whether assignment linked.

alter table public.note_tasks
  add column assignee_user_id uuid
    references auth.users (id) on delete set null,
  add column assignee_email text,
  add column assignee_display_name text,
  add column source_assignee jsonb;

alter table public.note_tasks
  add constraint note_tasks_assignee_email_check
    check (
      assignee_email is null
      or assignee_email ~
        '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),
  add constraint note_tasks_source_assignee_check
    check (
      source_assignee is null
      or jsonb_typeof(source_assignee) = 'object'
    );

create index note_tasks_assignee_status_due_idx
  on public.note_tasks (assignee_user_id, status, due_at)
  where assignee_user_id is not null;

create or replace function
  evernote_migration_private.hydrate_evernote_task_assignee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source jsonb;
  v_email text;
  v_display_name text;
  v_assignee_user_id uuid;
begin
  if new.source_system <> 'evernote' then
    return new;
  end if;

  v_source := nullif(new.source_metadata->'assignee', 'null'::jsonb);
  if v_source is null then
    new.source_assignee := null;
    return new;
  end if;
  if jsonb_typeof(v_source) <> 'object' then
    raise exception using
      errcode = '22023',
      message = 'Evernote Task assignee metadata must be an object.';
  end if;

  new.source_assignee := v_source;
  if new.assignee_user_id is not null
     or new.assignee_email is not null
     or new.assignee_display_name is not null then
    return new;
  end if;

  v_email := nullif(lower(btrim(v_source->>'email')), '');
  v_display_name := nullif(btrim(v_source->>'display_name'), '');
  if v_email is not null then
    select id
    into v_assignee_user_id
    from auth.users
    where lower(email) = v_email
    order by id
    limit 1;
  end if;

  new.assignee_user_id := v_assignee_user_id;
  new.assignee_email := v_email;
  new.assignee_display_name := v_display_name;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.hydrate_evernote_task_assignee()
  from public, anon, authenticated, service_role;

create trigger hydrate_imported_note_task_assignee
  before insert or update of source_metadata
  on public.note_tasks
  for each row
  execute function
    evernote_migration_private.hydrate_evernote_task_assignee();

create or replace function
  evernote_migration_private.protect_imported_task_assignee_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.source_system = 'evernote'
     and new.source_assignee is distinct from old.source_assignee then
    raise exception using
      errcode = '23514',
      message = 'Imported Evernote Task assignee evidence is immutable.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.protect_imported_task_assignee_source()
  from public, anon, authenticated, service_role;

create trigger protect_imported_task_assignee_source
  before update of source_assignee
  on public.note_tasks
  for each row
  execute function
    evernote_migration_private.protect_imported_task_assignee_source();

drop policy note_tasks_select_owner on public.note_tasks;
create policy note_tasks_select_owner_or_assignee
  on public.note_tasks
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or (select auth.uid()) = assignee_user_id
  );

drop policy note_task_reminders_select_owner
  on public.note_task_reminders;
create policy note_task_reminders_select_owner_or_assignee
  on public.note_task_reminders
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1
      from public.note_tasks as task
      where task.id = note_task_reminders.task_id
        and task.user_id = note_task_reminders.user_id
        and task.assignee_user_id = (select auth.uid())
    )
  );

create or replace function public.note_task_assign(
  p_task_id uuid,
  p_assignee_email text,
  p_assignee_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_email text := nullif(lower(btrim(p_assignee_email)), '');
  v_display_name text := nullif(btrim(p_assignee_display_name), '');
  v_assignee_user_id uuid;
  v_task_id uuid;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if v_email is not null
     and v_email !~
       '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception using
      errcode = '22023',
      message = 'The Task assignee email is invalid.';
  end if;

  select id
  into v_task_id
  from public.note_tasks
  where id = p_task_id
    and user_id = v_user_id
  for update;

  if v_task_id is null then
    raise exception using
      errcode = '42501',
      message = 'Only the Task owner can change its assignee.';
  end if;

  if v_email is not null then
    select id
    into v_assignee_user_id
    from auth.users
    where lower(email) = v_email
    order by id
    limit 1;
  end if;

  update public.note_tasks
  set
    assignee_user_id = v_assignee_user_id,
    assignee_email = v_email,
    assignee_display_name = case
      when v_email is null then null
      else coalesce(v_display_name, v_email)
    end,
    updated_at = clock_timestamp()
  where id = v_task_id
    and user_id = v_user_id;

  return jsonb_build_object(
    'task_id', v_task_id,
    'assigned', v_email is not null,
    'linked_account', v_assignee_user_id is not null,
    'assignee_email', v_email,
    'assignee_display_name', case
      when v_email is null then null
      else coalesce(v_display_name, v_email)
    end
  );
end
$$;

create or replace function public.note_task_set_completion(
  p_task_id uuid,
  p_completed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_status text;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  update public.note_tasks
  set
    status = case when p_completed then 'completed' else 'open' end,
    status_updated_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where id = p_task_id
    and (
      user_id = v_user_id
      or assignee_user_id = v_user_id
    )
  returning status into v_status;

  if v_status is null then
    raise exception using
      errcode = '42501',
      message = 'The Task is not owned by or assigned to this user.';
  end if;

  return jsonb_build_object(
    'task_id', p_task_id,
    'status', v_status
  );
end
$$;

revoke all on function public.note_task_assign(uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.note_task_set_completion(uuid, boolean)
  from public, anon, authenticated, service_role;

grant execute on function public.note_task_assign(uuid, text, text)
  to authenticated;
grant execute on function public.note_task_set_completion(uuid, boolean)
  to authenticated;

comment on function public.note_task_assign(uuid, text, text) is
  'Owner-only Task assignment with exact-email local account linking.';
comment on function public.note_task_set_completion(uuid, boolean) is
  'Allows a Task owner or linked assignee to change completion only.';
comment on column public.note_tasks.source_assignee is
  'Immutable assignee evidence parsed from the Evernote Task payload.';
