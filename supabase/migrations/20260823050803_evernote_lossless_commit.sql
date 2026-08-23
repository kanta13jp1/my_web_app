-- Loss-preserving Evernote commit pipeline.
--
-- Storage uploads happen before the database commit. The RPC below then
-- verifies that every owner-scoped object exists and atomically creates the
-- note, attachment metadata, and migration-ledger transition. Deterministic
-- content-addressed paths make retries safe after an interrupted upload.

alter table public.evernote_migration_batches
  add column source_archive_bucket text,
  add column source_archive_path text,
  add column source_archived_at timestamptz;

alter table public.evernote_migration_batches
  add constraint evernote_migration_batches_archive_pair_check
  check (
    (source_archive_bucket is null and source_archive_path is null)
    or (source_archive_bucket is not null and source_archive_path is not null)
  );

alter table public.evernote_migration_items
  add column source_enml text,
  add column source_metadata jsonb not null default '{}'::jsonb,
  add column verified_resource_count bigint not null default 0;

alter table public.evernote_migration_items
  add constraint evernote_migration_items_verified_resource_count_check
    check (
      verified_resource_count between 0 and source_resource_count
    ),
  add constraint evernote_migration_items_target_note_fkey
    foreign key (target_note_id)
    references public.notes(id)
    on delete set null;

create index evernote_migration_items_target_note_idx
  on public.evernote_migration_items (target_note_id)
  where target_note_id is not null;

-- nocheck: time-relative
-- The detector treats schema-qualified `update public.<table>` statements as
-- updates to a table named `public`. This migration updates only the newly
-- introduced Evernote migration ledger tables; none has a time-relative
-- enforcement trigger.

alter table public.attachments
  add column content_sha256 text,
  add column source_system text,
  add column source_metadata jsonb not null default '{}'::jsonb;

alter table public.attachments
  add constraint attachments_file_size_nonnegative_check
    check (file_size >= 0),
  add constraint attachments_content_sha256_format_check
    check (
      content_sha256 is null
      or content_sha256 ~ '^[0-9a-f]{64}$'
    ),
  add constraint attachments_source_system_check
    check (source_system is null or source_system = 'evernote'),
  add constraint attachments_evernote_hash_required_check
    check (source_system <> 'evernote' or content_sha256 is not null);

create index attachments_user_content_sha256_idx
  on public.attachments (user_id, content_sha256)
  where content_sha256 is not null;

-- Evernote supports arbitrary attachment MIME types. The normal attachment
-- picker keeps its existing 5 MB/type UI guard, while the verified migration
-- path may store larger or non-previewable files.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'attachments',
  'attachments',
  false,
  104857600,
  null
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'evernote-migration-archives',
  'evernote-migration-archives',
  false,
  104857600,
  null
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Remove legacy PUBLIC attachment policies. The authenticated-only policies
-- from 20260606023000_harden_attachment_direct_upload.sql remain active.
drop policy if exists "Users can upload their own attachments"
  on storage.objects;
drop policy if exists "Users can view their own attachments"
  on storage.objects;
drop policy if exists "Users can delete their own attachments"
  on storage.objects;

drop policy if exists "Evernote archive owners can upload"
  on storage.objects;
drop policy if exists "Evernote archive owners can read"
  on storage.objects;

create policy "Evernote archive owners can upload"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'evernote-migration-archives'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Evernote archive owners can read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'evernote-migration-archives'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Strengthen attachment ownership so an authenticated user cannot attach a
-- file to another user's note even when they know its numeric id.
drop policy if exists "Users can view their own attachments"
  on public.attachments;
drop policy if exists "Users can insert their own attachments"
  on public.attachments;
drop policy if exists "Users can update their own attachments"
  on public.attachments;
drop policy if exists "Users can delete their own attachments"
  on public.attachments;

create policy "Users can view their own attachments"
  on public.attachments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own attachments"
  on public.attachments
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.notes
      where notes.id = attachments.note_id
        and notes.user_id = (select auth.uid())
    )
  );

create policy "Users can update their own attachments"
  on public.attachments
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.notes
      where notes.id = attachments.note_id
        and notes.user_id = (select auth.uid())
    )
  );

create policy "Users can delete their own attachments"
  on public.attachments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.evernote_commit_note(
  p_batch_id bigint,
  p_source_item_key text,
  p_title text,
  p_content text,
  p_source_created_at timestamptz,
  p_source_updated_at timestamptz,
  p_tags text[],
  p_source_enml text,
  p_source_metadata jsonb,
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
  v_batch public.evernote_migration_batches%rowtype;
  v_item public.evernote_migration_items%rowtype;
  v_note_id bigint;
  v_resource_count bigint;
  v_imported_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into v_batch
  from public.evernote_migration_batches
  where id = p_batch_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'Evernote migration batch was not found.';
  end if;

  select *
  into v_item
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key
  for update;

  if not found then
    raise exception 'Evernote migration item was not found.';
  end if;

  if v_item.target_note_id is not null
     and v_item.status in (
       'imported',
       'verifying',
       'verified',
       'source_deleting',
       'source_deleted'
     ) then
    return jsonb_build_object(
      'note_id', v_item.target_note_id,
      'status', v_item.status,
      'reused', true
    );
  end if;

  if p_archive_bucket <> 'evernote-migration-archives'
     or p_archive_path <>
       v_user_id::text || '/evernote/' ||
       v_batch.source_export_sha256 || '/source.enex' then
    raise exception 'Evernote source archive path is invalid.';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = p_archive_bucket
      and name = p_archive_path
  ) then
    raise exception 'Evernote source archive is missing.';
  end if;

  if p_resources is null or jsonb_typeof(p_resources) <> 'array' then
    raise exception 'Evernote resources must be a JSON array.';
  end if;

  if jsonb_array_length(p_resources) <> v_item.source_resource_count then
    raise exception 'Evernote resource manifest count does not match preview.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_resources) as resource(value)
    where coalesce(resource.value->>'file_path', '') not like
      v_user_id::text || '/evernote/' ||
      v_batch.source_export_sha256 || '/%'
      or coalesce(resource.value->>'content_sha256', '') !~
        '^[0-9a-f]{64}$'
      or coalesce(resource.value->>'file_size', '') !~ '^[0-9]+$'
      or coalesce(resource.value->>'mime_type', '') = ''
  ) then
    raise exception 'Evernote resource manifest is invalid.';
  end if;

  select count(*)
  into v_resource_count
  from jsonb_array_elements(p_resources) as resource(value)
  where exists (
    select 1
    from storage.objects
    where bucket_id = 'attachments'
      and name = resource.value->>'file_path'
  );

  if v_resource_count <> v_item.source_resource_count then
    raise exception 'One or more Evernote attachment objects are missing.';
  end if;

  insert into public.notes (
    user_id,
    title,
    content,
    created_at,
    updated_at,
    tags,
    is_archived,
    is_pinned
  )
  values (
    v_user_id,
    p_title,
    p_content,
    coalesce(p_source_created_at, now()),
    coalesce(p_source_updated_at, p_source_created_at, now()),
    coalesce(p_tags, '{}'::text[]),
    false,
    false
  )
  returning id into v_note_id;

  insert into public.attachments (
    note_id,
    user_id,
    file_name,
    file_path,
    file_size,
    file_type,
    mime_type,
    content_sha256,
    source_system,
    source_metadata
  )
  select
    v_note_id,
    v_user_id,
    coalesce(nullif(resource.value->>'file_name', ''), 'Evernote attachment'),
    resource.value->>'file_path',
    (resource.value->>'file_size')::bigint,
    coalesce(nullif(resource.value->>'file_type', ''), 'other'),
    resource.value->>'mime_type',
    resource.value->>'content_sha256',
    'evernote',
    coalesce(resource.value->'source_metadata', '{}'::jsonb)
  from jsonb_array_elements(p_resources) as resource(value)
  on conflict (file_path) do nothing;

  select count(*)
  into v_resource_count
  from public.attachments
  where note_id = v_note_id
    and user_id = v_user_id
    and source_system = 'evernote';

  if v_resource_count <> v_item.source_resource_count then
    raise exception 'Evernote attachment metadata commit is incomplete.';
  end if;

  update public.evernote_migration_items
  set
    target_note_id = v_note_id,
    source_enml = p_source_enml,
    source_metadata = coalesce(p_source_metadata, '{}'::jsonb),
    status = 'imported',
    last_error = null,
    imported_at = now(),
    updated_at = now()
  where id = v_item.id;

  select count(*)
  into v_imported_count
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and status in (
      'imported',
      'verifying',
      'verified',
      'source_deleting',
      'source_deleted'
    );

  update public.evernote_migration_batches
  set
    source_archive_bucket = p_archive_bucket,
    source_archive_path = p_archive_path,
    source_archived_at = coalesce(source_archived_at, now()),
    imported_note_count = v_imported_count,
    status = case
      when v_imported_count = source_note_count then 'imported'
      else 'importing'
    end,
    imported_at = case
      when v_imported_count = source_note_count then coalesce(imported_at, now())
      else imported_at
    end,
    last_error = null,
    updated_at = now()
  where id = p_batch_id
    and user_id = v_user_id;

  return jsonb_build_object(
    'note_id', v_note_id,
    'status', 'imported',
    'reused', false
  );
end;
$$;

create or replace function public.evernote_verify_note(
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
  v_batch public.evernote_migration_batches%rowtype;
  v_item public.evernote_migration_items%rowtype;
  v_resource_count bigint;
  v_verified_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  select *
  into v_batch
  from public.evernote_migration_batches
  where id = p_batch_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'Evernote migration batch was not found.';
  end if;

  select *
  into v_item
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key
  for update;

  if not found or v_item.target_note_id is null then
    raise exception 'Evernote migration item has not been imported.';
  end if;

  if v_item.status in ('verified', 'source_deleting', 'source_deleted') then
    return jsonb_build_object(
      'note_id', v_item.target_note_id,
      'status', v_item.status,
      'reused', true
    );
  end if;

  if p_verification_checks is null
     or jsonb_typeof(p_verification_checks) <> 'object'
     or coalesce((p_verification_checks->>'archive_sha256')::boolean, false) is not true
     or coalesce((p_verification_checks->>'note_content')::boolean, false) is not true
     or coalesce((p_verification_checks->>'timestamps')::boolean, false) is not true
     or coalesce((p_verification_checks->>'tags')::boolean, false) is not true
     or coalesce((p_verification_checks->>'resource_count')::boolean, false) is not true
     or coalesce((p_verification_checks->>'resource_sha256')::boolean, false) is not true then
    raise exception 'All Evernote verification checks must pass.';
  end if;

  if not exists (
    select 1
    from public.notes
    where id = v_item.target_note_id
      and user_id = v_user_id
  ) then
    raise exception 'Imported Evernote note is missing.';
  end if;

  select count(*)
  into v_resource_count
  from public.attachments
  where note_id = v_item.target_note_id
    and user_id = v_user_id
    and source_system = 'evernote'
    and content_sha256 is not null;

  if v_resource_count <> v_item.source_resource_count then
    raise exception 'Imported Evernote attachment metadata is incomplete.';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = v_batch.source_archive_bucket
      and name = v_batch.source_archive_path
  ) then
    raise exception 'Evernote recovery archive is missing.';
  end if;

  if exists (
    select 1
    from public.attachments
    where note_id = v_item.target_note_id
      and user_id = v_user_id
      and source_system = 'evernote'
      and not exists (
        select 1
        from storage.objects
        where bucket_id = 'attachments'
          and name = attachments.file_path
      )
  ) then
    raise exception 'An imported Evernote attachment object is missing.';
  end if;

  update public.evernote_migration_items
  set
    status = 'verified',
    verified_resource_count = v_resource_count,
    verification_checks = p_verification_checks,
    last_error = null,
    verified_at = now(),
    updated_at = now()
  where id = v_item.id;

  select count(*)
  into v_verified_count
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and status in ('verified', 'source_deleting', 'source_deleted');

  update public.evernote_migration_batches
  set
    verified_note_count = v_verified_count,
    status = case
      when v_verified_count = source_note_count then 'verified'
      else 'verifying'
    end,
    verified_at = case
      when v_verified_count = source_note_count then coalesce(verified_at, now())
      else verified_at
    end,
    verification_summary = jsonb_build_object(
      'verified_notes', v_verified_count,
      'source_notes', source_note_count,
      'last_checks', p_verification_checks
    ),
    last_error = null,
    updated_at = now()
  where id = p_batch_id
    and user_id = v_user_id;

  return jsonb_build_object(
    'note_id', v_item.target_note_id,
    'status', 'verified',
    'reused', false
  );
end;
$$;

revoke all on function public.evernote_commit_note(
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
  text,
  text
) from public, anon, authenticated, service_role;

revoke all on function public.evernote_verify_note(
  bigint,
  text,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.evernote_commit_note(
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
  text,
  text
) to authenticated;

grant execute on function public.evernote_verify_note(
  bigint,
  text,
  jsonb
) to authenticated;

comment on function public.evernote_commit_note(
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
  text,
  text
) is 'Atomically commits an owner-scoped Evernote note after its content-addressed Storage objects exist.';

comment on function public.evernote_verify_note(
  bigint,
  text,
  jsonb
) is 'Marks an Evernote item verified only after client hash checks and server object/count checks pass.';
