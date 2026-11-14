\set ON_ERROR_STOP on

set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  false
);

do $$
begin
  begin
    perform public.evernote_commit_tag_inventory(
      jsonb_build_array(
        jsonb_build_object(
          'source_key', 'tag:orphan',
          'name', 'Orphan',
          'parent_source_key', 'tag:missing'
        )
      )
    );
    raise exception 'An unresolved parent unexpectedly succeeded.';
  exception
    when invalid_parameter_value then
      null;
  end;
end
$$;

select public.evernote_commit_tag_inventory(
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'tag:work',
      'name', 'Work',
      'parent_source_key', null
    ),
    jsonb_build_object(
      'source_key', 'tag:migration',
      'name', 'migration',
      'parent_source_key', 'tag:work'
    )
  )
);

-- Exact inventory replay must be idempotent.
select public.evernote_commit_tag_inventory(
  jsonb_build_array(
    jsonb_build_object(
      'source_key', 'tag:work',
      'name', 'Work',
      'parent_source_key', null
    ),
    jsonb_build_object(
      'source_key', 'tag:migration',
      'name', 'migration',
      'parent_source_key', 'tag:work'
    )
  )
);

do $$
declare
  v_parent_id bigint;
begin
  select id into strict v_parent_id
  from public.note_tags
  where user_id = '00000000-0000-4000-8000-000000000101'
    and source_key = 'tag:work';

  if (
    select count(*)
    from public.note_tags
    where user_id = '00000000-0000-4000-8000-000000000101'
      and source_system = 'evernote'
  ) <> 2 then
    raise exception 'Tag replay created a duplicate.';
  end if;

  if (
    select parent_id
    from public.note_tags
    where user_id = '00000000-0000-4000-8000-000000000101'
      and source_key = 'tag:migration'
  ) <> v_parent_id then
    raise exception 'The nested tag parent was not resolved.';
  end if;

  if (
    select count(*)
    from public.note_tag_assignments
    where user_id = '00000000-0000-4000-8000-000000000101'
      and source_system = 'evernote'
  ) <> 1 then
    raise exception 'The imported note/tag assignment was not materialized.';
  end if;

  if (
    select char_length(source_snapshot_sha256)
    from public.evernote_tag_migrations
    where user_id = '00000000-0000-4000-8000-000000000101'
  ) <> 64 then
    raise exception 'The tag inventory snapshot hash was not retained.';
  end if;

  if exists (
    select 1
    from public.note_tags
    where source_system = 'evernote'
      and char_length(source_sha256) <> 64
  ) or exists (
    select 1
    from public.note_tag_assignments
    where source_system = 'evernote'
      and char_length(source_sha256) <> 64
  ) then
    raise exception 'A tag evidence hash was not retained.';
  end if;
end
$$;

do $$
begin
  begin
    perform public.evernote_verify_tag_inventory(
      jsonb_build_object(
        'tag_count', true,
        'tag_names', true,
        'tag_hierarchy', true,
        'assignment_count', true,
        'assignments', false
      )
    );
    raise exception 'Incomplete tag verification unexpectedly succeeded.';
  exception
    when check_violation then
      null;
  end;
end
$$;

select public.evernote_verify_tag_inventory(
  jsonb_build_object(
    'tag_count', true,
    'tag_names', true,
    'tag_hierarchy', true,
    'assignment_count', true,
    'assignments', true
  )
);

do $$
begin
  if (
    select status
    from public.evernote_tag_migrations
    where user_id = '00000000-0000-4000-8000-000000000101'
  ) <> 'verified' then
    raise exception 'The verified tag inventory state was not stored.';
  end if;

  begin
    update public.note_tags
    set name = 'Changed'
    where source_key = 'tag:migration';
    raise exception 'Imported tag evidence was mutable.';
  exception
    when check_violation then
      null;
  end;

  begin
    delete from public.note_tag_assignments
    where source_system = 'evernote';
    raise exception 'Imported tag assignment evidence was deletable.';
  exception
    when check_violation then
      null;
  end;
end
$$;

-- Native nested-tag CRUD remains available and cyclic parents are rejected.
insert into public.note_tags (user_id, name)
values (
  '00000000-0000-4000-8000-000000000101',
  'Native parent'
);

insert into public.note_tags (user_id, parent_id, name)
select
  '00000000-0000-4000-8000-000000000101',
  id,
  'Native child'
from public.note_tags
where user_id = '00000000-0000-4000-8000-000000000101'
  and name = 'Native parent';

do $$
begin
  begin
    update public.note_tags
    set parent_id = (
      select id
      from public.note_tags
      where user_id = '00000000-0000-4000-8000-000000000101'
        and name = 'Native child'
    )
    where user_id = '00000000-0000-4000-8000-000000000101'
      and name = 'Native parent';
    raise exception 'A cyclic native tag hierarchy unexpectedly succeeded.';
  exception
    when check_violation then
      null;
  end;
end
$$;

-- A different owner cannot read the first owner's hierarchy or ledger.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  false
);

do $$
begin
  if (select count(*) from public.note_tags) <> 0
     or (select count(*) from public.note_tag_assignments) <> 0
     or (select count(*) from public.evernote_tag_migrations) <> 0 then
    raise exception 'Cross-owner tag rows leaked through RLS.';
  end if;
end
$$;

-- An explicit zero-item inventory is valid and still required for deletion.
select public.evernote_commit_tag_inventory('[]'::jsonb);
select public.evernote_verify_tag_inventory(
  jsonb_build_object(
    'tag_count', true,
    'tag_names', true,
    'tag_hierarchy', true,
    'assignment_count', true,
    'assignments', true
  )
);

do $$
begin
  if (
    select status = 'verified'
      and source_tag_count = 0
      and source_assignment_count = 0
      and char_length(source_snapshot_sha256) = 64
    from public.evernote_tag_migrations
  ) is not true then
    raise exception 'Explicit zero-tag inventory was not verified.';
  end if;
end
$$;

reset role;
