-- Add Evernote-compatible Space membership, invitations, and shared notes.
--
-- Space contents inherit one of three permissions: full access, edit, or view.
-- Invitations are email-bound and can only be claimed by a matching JWT email.
-- Shared notes remain owned by the Space owner; created_by preserves authorship.
--
-- nocheck: time-relative
-- User-driven membership changes use clock_timestamp().

create table public.note_space_members (
  space_id bigint not null,
  owner_id uuid not null,
  member_user_id uuid not null references auth.users (id) on delete cascade,
  member_email text not null,
  permission text not null,
  added_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (space_id, member_user_id),
  constraint note_space_members_space_owner_fkey
    foreign key (space_id, owner_id)
    references public.note_collections (id, user_id)
    on delete cascade,
  constraint note_space_members_not_owner_check
    check (member_user_id <> owner_id),
  constraint note_space_members_email_check
    check (
      member_email = lower(btrim(member_email))
      and position('@' in member_email) > 1
      and char_length(member_email) <= 320
    ),
  constraint note_space_members_permission_check
    check (permission in ('full_access', 'edit', 'view'))
);

create index note_space_members_member_idx
  on public.note_space_members (member_user_id, space_id);
create index note_space_members_owner_idx
  on public.note_space_members (owner_id, space_id);

create table public.note_space_invitations (
  id uuid primary key default gen_random_uuid(),
  space_id bigint not null,
  owner_id uuid not null,
  space_name text not null,
  invitee_email text not null,
  permission text not null,
  status text not null default 'pending',
  invited_by uuid not null references auth.users (id) on delete restrict,
  accepted_by uuid references auth.users (id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint note_space_invitations_space_owner_fkey
    foreign key (space_id, owner_id)
    references public.note_collections (id, user_id)
    on delete cascade,
  constraint note_space_invitations_space_name_check
    check (char_length(btrim(space_name)) between 1 and 200),
  constraint note_space_invitations_email_check
    check (
      invitee_email = lower(btrim(invitee_email))
      and position('@' in invitee_email) > 1
      and char_length(invitee_email) <= 320
    ),
  constraint note_space_invitations_permission_check
    check (permission in ('full_access', 'edit', 'view')),
  constraint note_space_invitations_status_check
    check (status in ('pending', 'accepted', 'declined', 'revoked', 'expired'))
);

create unique index note_space_invitations_pending_email_idx
  on public.note_space_invitations (space_id, invitee_email)
  where status = 'pending';
create index note_space_invitations_invitee_idx
  on public.note_space_invitations (invitee_email, status, created_at desc);
create index note_space_invitations_owner_idx
  on public.note_space_invitations (owner_id, space_id, status);

create or replace function
  evernote_migration_private.note_collection_space_id(
    p_collection_id bigint,
    p_owner_id uuid
  )
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when child.collection_type = 'space' then child.id
    when child.collection_type = 'stack'
      and parent.collection_type = 'space' then parent.id
    when child.collection_type = 'notebook'
      and parent.collection_type = 'space' then parent.id
    when child.collection_type = 'notebook'
      and parent.collection_type = 'stack'
      and grandparent.collection_type = 'space' then grandparent.id
    else null
  end
  from public.note_collections child
  left join public.note_collections parent
    on parent.id = child.parent_id
   and parent.user_id = child.user_id
  left join public.note_collections grandparent
    on grandparent.id = parent.parent_id
   and grandparent.user_id = parent.user_id
  where child.id = p_collection_id
    and child.user_id = p_owner_id;
$$;

create or replace function
  evernote_migration_private.note_space_permission(p_space_id bigint)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when space.user_id = (select auth.uid()) then 'owner'
    else member.permission
  end
  from public.note_collections space
  left join public.note_space_members member
    on member.space_id = space.id
   and member.owner_id = space.user_id
   and member.member_user_id = (select auth.uid())
  where space.id = p_space_id
    and space.collection_type = 'space'
    and (
      space.user_id = (select auth.uid())
      or member.member_user_id is not null
    );
$$;

create or replace function
  evernote_migration_private.can_read_note_space(p_space_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    evernote_migration_private.note_space_permission(p_space_id)
      in ('owner', 'full_access', 'edit', 'view'),
    false
  );
$$;

create or replace function
  evernote_migration_private.can_edit_note_space(p_space_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    evernote_migration_private.note_space_permission(p_space_id)
      in ('owner', 'full_access', 'edit'),
    false
  );
$$;

create or replace function
  evernote_migration_private.can_manage_note_space(p_space_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    evernote_migration_private.note_space_permission(p_space_id)
      in ('owner', 'full_access'),
    false
  );
$$;

revoke all on function
  evernote_migration_private.note_collection_space_id(bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function
  evernote_migration_private.note_space_permission(bigint)
  from public, anon, authenticated, service_role;
revoke all on function
  evernote_migration_private.can_read_note_space(bigint)
  from public, anon, authenticated, service_role;
revoke all on function
  evernote_migration_private.can_edit_note_space(bigint)
  from public, anon, authenticated, service_role;
revoke all on function
  evernote_migration_private.can_manage_note_space(bigint)
  from public, anon, authenticated, service_role;

grant usage on schema evernote_migration_private to authenticated;
grant execute on function
  evernote_migration_private.note_collection_space_id(bigint, uuid)
  to authenticated;
grant execute on function
  evernote_migration_private.note_space_permission(bigint)
  to authenticated;
grant execute on function
  evernote_migration_private.can_read_note_space(bigint)
  to authenticated;
grant execute on function
  evernote_migration_private.can_edit_note_space(bigint)
  to authenticated;
grant execute on function
  evernote_migration_private.can_manage_note_space(bigint)
  to authenticated;

alter table public.note_space_members enable row level security;
alter table public.note_space_invitations enable row level security;

create policy note_space_members_select_participant
  on public.note_space_members
  for select
  to authenticated
  using (
    evernote_migration_private.can_read_note_space(space_id)
  );

create policy note_space_invitations_select_manager_or_invitee
  on public.note_space_invitations
  for select
  to authenticated
  using (
    evernote_migration_private.can_manage_note_space(space_id)
    or (
      status = 'pending'
      and invitee_email = lower(coalesce((select auth.jwt()->>'email'), ''))
    )
  );

revoke all on table public.note_space_members
  from public, anon, authenticated, service_role;
revoke all on table public.note_space_invitations
  from public, anon, authenticated, service_role;
grant select on table public.note_space_members to authenticated;
grant select on table public.note_space_invitations to authenticated;
grant all on table public.note_space_members to service_role;
grant all on table public.note_space_invitations to service_role;

drop policy if exists note_collections_select_shared_space
  on public.note_collections;
create policy note_collections_select_shared_space
  on public.note_collections
  for select
  to authenticated
  using (
    evernote_migration_private.can_read_note_space(
      evernote_migration_private.note_collection_space_id(id, user_id)
    )
  );

alter table public.notes
  add column if not exists created_by uuid references auth.users (id)
    on delete restrict,
  add column if not exists space_collection_id bigint;

update public.notes
set created_by = user_id
where created_by is null;

alter table public.notes
  alter column created_by set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notes_space_collection_owner_fkey'
      and conrelid = 'public.notes'::regclass
  ) then
    alter table public.notes
      add constraint notes_space_collection_owner_fkey
      foreign key (space_collection_id, user_id)
      references public.note_collections (id, user_id)
      on delete restrict;
  end if;
end
$$;

update public.notes note
set space_collection_id =
  evernote_migration_private.note_collection_space_id(
    note.notebook_collection_id,
    note.user_id
  )
where note.notebook_collection_id is not null
  and note.space_collection_id is null;

create index if not exists notes_space_collection_idx
  on public.notes (space_collection_id, updated_at desc, id desc)
  where space_collection_id is not null;
create index if not exists notes_created_by_idx
  on public.notes (created_by, updated_at desc);

grant select (created_by, space_collection_id)
  on table public.notes to authenticated;
grant insert (created_by, space_collection_id)
  on table public.notes to authenticated;
grant update (space_collection_id)
  on table public.notes to authenticated;

create or replace function
  evernote_migration_private.validate_note_notebook_collection()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_notebook_type text;
  v_notebook_space bigint;
  v_space_owner uuid;
  v_space_type text;
  v_old_space bigint;
begin
  if v_actor is null then
    if new.created_by is null then
      new.created_by := new.user_id;
    end if;
  else
    if tg_op = 'INSERT' and new.created_by is null then
      new.created_by := v_actor;
    end if;

    if tg_op = 'UPDATE' then
      if new.user_id is distinct from old.user_id then
        raise exception using
          errcode = '42501',
          message = 'Shared note ownership is immutable.';
      end if;
      if new.created_by is distinct from old.created_by then
        raise exception using
          errcode = '42501',
          message = 'Shared note authorship is immutable.';
      end if;
    end if;
  end if;

  if new.notebook_collection_id is not null then
    select
      notebook.collection_type,
      evernote_migration_private.note_collection_space_id(
        notebook.id,
        notebook.user_id
      )
    into v_notebook_type, v_notebook_space
    from public.note_collections notebook
    where notebook.id = new.notebook_collection_id
      and notebook.user_id = new.user_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The notebook does not exist for the note owner.';
    end if;

    if v_notebook_type <> 'notebook' then
      raise exception using
        errcode = '23514',
        message = 'Notes can only be assigned to notebook collections.';
    end if;
  else
    v_notebook_space := null;
  end if;

  if new.space_collection_id is null and v_notebook_space is not null then
    new.space_collection_id := v_notebook_space;
  end if;

  if new.space_collection_id is not null then
    select user_id, collection_type
    into v_space_owner, v_space_type
    from public.note_collections
    where id = new.space_collection_id;

    if not found
       or v_space_type <> 'space'
       or v_space_owner <> new.user_id
    then
      raise exception using
        errcode = '23514',
        message = 'The shared Space must belong to the note owner.';
    end if;

    if new.notebook_collection_id is not null
       and v_notebook_space is distinct from new.space_collection_id
    then
      raise exception using
        errcode = '23514',
        message = 'The notebook must belong to the same shared Space.';
    end if;
  elsif new.notebook_collection_id is null
        and v_actor is not null
        and new.user_id <> v_actor
  then
    raise exception using
      errcode = '42501',
      message = 'A member cannot create an unshared note for another owner.';
  end if;

  if v_actor is null or new.user_id = v_actor then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.created_by <> v_actor
       or not evernote_migration_private.can_edit_note_space(
         new.space_collection_id
       )
    then
      raise exception using
        errcode = '42501',
        message = 'Edit access to the Space is required to create this note.';
    end if;
    return new;
  end if;

  v_old_space := old.space_collection_id;
  if v_old_space is null
     or new.space_collection_id is distinct from v_old_space
     or not evernote_migration_private.can_edit_note_space(v_old_space)
  then
    raise exception using
      errcode = '42501',
      message = 'Members can reorganize notes only within an editable Space.';
  end if;

  return new;
end
$$;

revoke all on function
  evernote_migration_private.validate_note_notebook_collection()
  from public, anon, authenticated, service_role;

drop trigger if exists validate_note_notebook_collection
  on public.notes;
create trigger validate_note_notebook_collection
  before insert or update of
    user_id,
    created_by,
    notebook_collection_id,
    space_collection_id
  on public.notes
  for each row
  execute function
    evernote_migration_private.validate_note_notebook_collection();

drop policy if exists notes_select_shared_space on public.notes;
create policy notes_select_shared_space
  on public.notes
  for select
  to authenticated
  using (
    space_collection_id is not null
    and evernote_migration_private.can_read_note_space(space_collection_id)
  );

drop policy if exists notes_update_shared_space on public.notes;
create policy notes_update_shared_space
  on public.notes
  for update
  to authenticated
  using (
    space_collection_id is not null
    and evernote_migration_private.can_edit_note_space(space_collection_id)
  )
  with check (
    space_collection_id is not null
    and evernote_migration_private.can_edit_note_space(space_collection_id)
  );

create or replace function public.invite_to_note_space(
  p_space_id bigint,
  p_invitee_email text,
  p_permission text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_email text := lower(btrim(p_invitee_email));
  v_owner uuid;
  v_space_name text;
  v_invitation_id uuid;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'Authentication is required.';
  end if;
  if p_permission not in ('full_access', 'edit', 'view') then
    raise exception using errcode = '22023', message = 'Unknown Space permission.';
  end if;
  if position('@' in v_email) <= 1 or char_length(v_email) > 320 then
    raise exception using errcode = '22023', message = 'A valid invite email is required.';
  end if;
  if not evernote_migration_private.can_manage_note_space(p_space_id) then
    raise exception using errcode = '42501', message = 'Full access to the Space is required.';
  end if;

  select user_id, name
  into v_owner, v_space_name
  from public.note_collections
  where id = p_space_id
    and collection_type = 'space'
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'The Space does not exist.';
  end if;

  if exists (
    select 1 from auth.users
    where id = v_owner and lower(email) = v_email
  ) then
    raise exception using errcode = '23514', message = 'The Space owner cannot be invited.';
  end if;

  insert into public.note_space_invitations (
    space_id,
    owner_id,
    space_name,
    invitee_email,
    permission,
    invited_by
  )
  values (
    p_space_id,
    v_owner,
    v_space_name,
    v_email,
    p_permission,
    v_actor
  )
  on conflict (space_id, invitee_email) where status = 'pending'
  do update set
    permission = excluded.permission,
    invited_by = excluded.invited_by,
    updated_at = clock_timestamp()
  returning id into v_invitation_id;

  return jsonb_build_object(
    'invitation_id', v_invitation_id,
    'space_id', p_space_id,
    'invitee_email', v_email,
    'permission', p_permission
  );
end
$$;

create or replace function public.accept_note_space_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_email text := lower(coalesce((select auth.jwt()->>'email'), ''));
  v_invitation public.note_space_invitations%rowtype;
begin
  if v_actor is null or v_email = '' then
    raise exception using errcode = '42501', message = 'An authenticated email is required.';
  end if;

  select *
  into v_invitation
  from public.note_space_invitations
  where id = p_invitation_id
  for update;

  if not found
     or v_invitation.status <> 'pending'
     or v_invitation.invitee_email <> v_email
     or (
       v_invitation.expires_at is not null
       and v_invitation.expires_at <= clock_timestamp()
     )
  then
    raise exception using errcode = '42501', message = 'This invitation cannot be accepted.';
  end if;

  insert into public.note_space_members (
    space_id,
    owner_id,
    member_user_id,
    member_email,
    permission,
    added_by
  )
  values (
    v_invitation.space_id,
    v_invitation.owner_id,
    v_actor,
    v_email,
    v_invitation.permission,
    v_invitation.invited_by
  )
  on conflict (space_id, member_user_id)
  do update set
    member_email = excluded.member_email,
    permission = excluded.permission,
    added_by = excluded.added_by,
    updated_at = clock_timestamp();

  update public.note_space_invitations
  set
    status = 'accepted',
    accepted_by = v_actor,
    updated_at = clock_timestamp()
  where id = p_invitation_id;

  return jsonb_build_object(
    'space_id', v_invitation.space_id,
    'permission', v_invitation.permission
  );
end
$$;

create or replace function public.decline_note_space_invitation(
  p_invitation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(coalesce((select auth.jwt()->>'email'), ''));
begin
  update public.note_space_invitations
  set status = 'declined', updated_at = clock_timestamp()
  where id = p_invitation_id
    and status = 'pending'
    and invitee_email = v_email;

  if not found then
    raise exception using errcode = '42501', message = 'This invitation cannot be declined.';
  end if;
end
$$;

create or replace function public.revoke_note_space_invitation(
  p_invitation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_space_id bigint;
begin
  select space_id into v_space_id
  from public.note_space_invitations
  where id = p_invitation_id
    and status = 'pending';

  if not found
     or not evernote_migration_private.can_manage_note_space(v_space_id)
  then
    raise exception using errcode = '42501', message = 'This invitation cannot be revoked.';
  end if;

  update public.note_space_invitations
  set status = 'revoked', updated_at = clock_timestamp()
  where id = p_invitation_id;
end
$$;

create or replace function public.update_note_space_member_permission(
  p_space_id bigint,
  p_member_user_id uuid,
  p_permission text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_permission not in ('full_access', 'edit', 'view') then
    raise exception using errcode = '22023', message = 'Unknown Space permission.';
  end if;
  if not evernote_migration_private.can_manage_note_space(p_space_id) then
    raise exception using errcode = '42501', message = 'Full access to the Space is required.';
  end if;

  update public.note_space_members
  set permission = p_permission, updated_at = clock_timestamp()
  where space_id = p_space_id
    and member_user_id = p_member_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The Space member does not exist.';
  end if;
end
$$;

create or replace function public.remove_note_space_member(
  p_space_id bigint,
  p_member_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null
     or (
       v_actor <> p_member_user_id
       and not evernote_migration_private.can_manage_note_space(p_space_id)
     )
  then
    raise exception using errcode = '42501', message = 'The Space member cannot be removed.';
  end if;

  delete from public.note_space_members
  where space_id = p_space_id
    and member_user_id = p_member_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The Space member does not exist.';
  end if;
end
$$;

create or replace function public.create_note_in_space(
  p_space_id bigint,
  p_title text,
  p_content text,
  p_notebook_collection_id bigint default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_owner uuid;
  v_note_id bigint;
begin
  if v_actor is null
     or not evernote_migration_private.can_edit_note_space(p_space_id)
  then
    raise exception using errcode = '42501', message = 'Edit access to the Space is required.';
  end if;

  select user_id into v_owner
  from public.note_collections
  where id = p_space_id
    and collection_type = 'space';

  if not found then
    raise exception using errcode = 'P0002', message = 'The Space does not exist.';
  end if;

  insert into public.notes (
    user_id,
    created_by,
    title,
    content,
    notebook_collection_id,
    space_collection_id
  )
  values (
    v_owner,
    v_actor,
    coalesce(p_title, ''),
    coalesce(p_content, ''),
    p_notebook_collection_id,
    p_space_id
  )
  returning id into v_note_id;

  return v_note_id;
end
$$;

create or replace function public.move_note_within_space(
  p_note_id bigint,
  p_destination_notebook_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_owner uuid;
  v_space_id bigint;
  v_destination_space bigint;
begin
  select user_id, space_collection_id
  into v_owner, v_space_id
  from public.notes
  where id = p_note_id
  for update;

  if not found
     or v_actor is null
     or v_space_id is null
     or not evernote_migration_private.can_edit_note_space(v_space_id)
  then
    raise exception using errcode = '42501', message = 'This shared note cannot be moved.';
  end if;

  if p_destination_notebook_id is not null then
    select evernote_migration_private.note_collection_space_id(
      p_destination_notebook_id,
      v_owner
    )
    into v_destination_space;

    if v_destination_space is distinct from v_space_id then
      raise exception using errcode = '23514', message = 'The destination must be in the same Space.';
    end if;
  end if;

  update public.notes
  set
    notebook_collection_id = p_destination_notebook_id,
    space_collection_id = v_space_id,
    updated_at = clock_timestamp()
  where id = p_note_id;

  return jsonb_build_object(
    'note_id', p_note_id,
    'space_id', v_space_id,
    'notebook_collection_id', p_destination_notebook_id
  );
end
$$;

revoke all on function public.invite_to_note_space(bigint, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.accept_note_space_invitation(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.decline_note_space_invitation(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.revoke_note_space_invitation(uuid)
  from public, anon, authenticated, service_role;
revoke all on function
  public.update_note_space_member_permission(bigint, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.remove_note_space_member(bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.create_note_in_space(bigint, text, text, bigint)
  from public, anon, authenticated, service_role;
revoke all on function public.move_note_within_space(bigint, bigint)
  from public, anon, authenticated, service_role;

grant execute on function public.invite_to_note_space(bigint, text, text)
  to authenticated;
grant execute on function public.accept_note_space_invitation(uuid)
  to authenticated;
grant execute on function public.decline_note_space_invitation(uuid)
  to authenticated;
grant execute on function public.revoke_note_space_invitation(uuid)
  to authenticated;
grant execute on function
  public.update_note_space_member_permission(bigint, uuid, text)
  to authenticated;
grant execute on function public.remove_note_space_member(bigint, uuid)
  to authenticated;
grant execute on function public.create_note_in_space(bigint, text, text, bigint)
  to authenticated;
grant execute on function public.move_note_within_space(bigint, bigint)
  to authenticated;

comment on table public.note_space_members is
  'Current participants and inherited permission for an Evernote-compatible Space.';
comment on table public.note_space_invitations is
  'Email-bound Space invitations claimable only by a matching authenticated JWT email.';
comment on column public.notes.created_by is
  'Authenticated author who originally created the owner-scoped note.';
comment on column public.notes.space_collection_id is
  'Effective Space whose inherited permission controls shared note access.';
