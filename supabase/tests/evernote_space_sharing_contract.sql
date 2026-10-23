\set ON_ERROR_STOP on

insert into auth.users (id, email)
values
  (
    '00000000-0000-4000-8000-000000000103',
    'viewer@example.com'
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    'outsider@example.com'
  );

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);
select set_config('request.jwt.claim.email', 'owner@example.com', false);

insert into public.note_collections (
  user_id,
  collection_type,
  name,
  description,
  source_system,
  sort_order
)
values (
  '00000000-0000-4000-8000-000000000101',
  'space',
  'Shared Space',
  'Synthetic permission contract',
  'native',
  90
);

insert into public.note_collections (
  user_id,
  collection_type,
  parent_id,
  name,
  source_system,
  sort_order
)
select
  '00000000-0000-4000-8000-000000000101',
  'notebook',
  id,
  'Shared Notebook',
  'native',
  10
from public.note_collections
where user_id = '00000000-0000-4000-8000-000000000101'
  and name = 'Shared Space';

select (
  public.invite_to_note_space(
    (
      select id
      from public.note_collections
      where user_id = '00000000-0000-4000-8000-000000000101'
        and name = 'Shared Space'
    ),
    'Delegate@Example.com',
    'edit'
  )->>'invitation_id'
) as delegate_invitation_id
\gset

select set_config(
  'test.other_notebook_id',
  (
    select id::text
    from public.note_collections
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Primary Notebook'
  ),
  false
);

do $$
begin
  if has_table_privilege(
    'authenticated',
    'public.note_space_members',
    'INSERT'
  ) then
    raise exception 'Direct Space membership insertion remains granted.';
  end if;

  if has_table_privilege(
    'authenticated',
    'public.note_space_invitations',
    'UPDATE'
  ) then
    raise exception 'Direct Space invitation mutation remains granted.';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);
select set_config('request.jwt.claim.email', 'delegate@example.com', false);

do $$
begin
  if (
    select count(*)
    from public.note_space_invitations
    where invitee_email = 'delegate@example.com'
      and status = 'pending'
      and invitee_email = 'delegate@example.com'
  ) <> 1 then
    raise exception 'The matching invitee could not read the pending invitation.';
  end if;
end
$$;

select public.accept_note_space_invitation(
  :'delegate_invitation_id'::uuid
);

do $$
begin
  if (
    select count(*)
    from public.note_collections
    where name in ('Shared Space', 'Shared Notebook')
  ) <> 2 then
    raise exception 'Accepted member cannot read the inherited Space tree.';
  end if;

  if (
    select permission
    from public.note_space_members
    where member_user_id = '00000000-0000-4000-8000-000000000102'
  ) <> 'edit' then
    raise exception 'Accepted membership did not retain edit permission.';
  end if;
end
$$;

select public.create_note_in_space(
  (
    select id
    from public.note_collections
    where name = 'Shared Space'
      and collection_type = 'space'
  ),
  'Delegate note',
  'Shared body',
  null
) as shared_note_id
\gset

do $$
begin
  if not exists (
    select 1
    from public.notes
    where title = 'Delegate note'
      and user_id = '00000000-0000-4000-8000-000000000101'
      and created_by = '00000000-0000-4000-8000-000000000102'
      and notebook_collection_id is null
      and space_collection_id = (
        select id
        from public.note_collections
        where name = 'Shared Space'
          and collection_type = 'space'
      )
  ) then
    raise exception 'Direct shared note ownership or authorship is incorrect.';
  end if;
end
$$;

update public.notes
set content = 'Edited by member'
where title = 'Delegate note';

select public.move_note_within_space(
  :'shared_note_id'::bigint,
  (
    select id
    from public.note_collections
    where name = 'Shared Notebook'
      and collection_type = 'notebook'
  )
);

do $$
begin
  if not exists (
    select 1
    from public.notes
    where title = 'Delegate note'
      and notebook_collection_id = (
        select id
        from public.note_collections
        where name = 'Shared Notebook'
      )
  ) then
    raise exception 'Editable member could not move the note within the Space.';
  end if;

  begin
    perform public.move_note_within_space(
      (
        select id
        from public.notes
        where title = 'Delegate note'
      ),
      current_setting('test.other_notebook_id')::bigint
    );
    raise exception 'Cross-Space note movement unexpectedly succeeded.';
  exception
    when check_violation then
      null;
  end;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);
select set_config('request.jwt.claim.email', 'owner@example.com', false);

select (
  public.invite_to_note_space(
    (
      select id
      from public.note_collections
      where name = 'Shared Space'
        and collection_type = 'space'
    ),
    'viewer@example.com',
    'view'
  )->>'invitation_id'
) as viewer_invitation_id
\gset

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103',
  false
);
select set_config('request.jwt.claim.email', 'viewer@example.com', false);
select public.accept_note_space_invitation(:'viewer_invitation_id'::uuid);

do $$
declare
  v_changed integer;
begin
  if (
    select count(*)
    from public.notes
    where title = 'Delegate note'
  ) <> 1 then
    raise exception 'View-only member cannot read the shared note.';
  end if;

  update public.notes
  set content = 'Viewer mutation'
  where title = 'Delegate note';
  get diagnostics v_changed = row_count;
  if v_changed <> 0 then
    raise exception 'View-only member unexpectedly updated a shared note.';
  end if;

  begin
    perform public.create_note_in_space(
      (
        select id
        from public.note_collections
        where name = 'Shared Space'
          and collection_type = 'space'
      ),
      'Forbidden viewer note',
      '',
      null
    );
    raise exception 'View-only member unexpectedly created a shared note.';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104',
  false
);
select set_config('request.jwt.claim.email', 'outsider@example.com', false);

do $$
begin
  if (
    select count(*)
    from public.note_collections
    where name in ('Shared Space', 'Shared Notebook')
  ) <> 0 then
    raise exception 'Outsider can read the shared Space tree.';
  end if;

  if (
    select count(*)
    from public.notes
    where title = 'Delegate note'
  ) <> 0 then
    raise exception 'Outsider can read a shared note.';
  end if;

  if (select count(*) from public.note_space_members) <> 0 then
    raise exception 'Outsider can read Space membership.';
  end if;

  if (select count(*) from public.note_space_invitations) <> 0 then
    raise exception 'Outsider can read Space invitations.';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);
select set_config('request.jwt.claim.email', 'owner@example.com', false);

select public.update_note_space_member_permission(
  (
    select id
    from public.note_collections
    where name = 'Shared Space'
      and collection_type = 'space'
  ),
  '00000000-0000-4000-8000-000000000103',
  'edit'
);

do $$
begin
  if (
    select permission
    from public.note_space_members
    where member_user_id = '00000000-0000-4000-8000-000000000103'
  ) <> 'edit' then
    raise exception 'Space manager could not update member permission.';
  end if;

  begin
    insert into public.note_space_members (
      space_id,
      owner_id,
      member_user_id,
      member_email,
      permission,
      added_by
    )
    values (
      (
        select id
        from public.note_collections
        where name = 'Shared Space'
          and collection_type = 'space'
      ),
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000104',
      'outsider@example.com',
      'edit',
      '00000000-0000-4000-8000-000000000101'
    );
    raise exception 'Direct membership DML unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);
select set_config('request.jwt.claim.email', 'delegate@example.com', false);

select public.remove_note_space_member(
  (
    select space_id
    from public.note_space_members
    where member_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  '00000000-0000-4000-8000-000000000102'
);

do $$
begin
  if (
    select count(*)
    from public.note_collections
    where name in ('Shared Space', 'Shared Notebook')
  ) <> 0 then
    raise exception 'A member retained Space access after leaving.';
  end if;

  if (
    select count(*)
    from public.notes
    where title = 'Delegate note'
  ) <> 0 then
    raise exception 'A member retained note access after leaving.';
  end if;
end
$$;

reset role;
