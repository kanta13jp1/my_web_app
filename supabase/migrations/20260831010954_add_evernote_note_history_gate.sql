-- Preserve separately exported Evernote note-history revisions and block
-- destructive source cleanup until every note's history was reviewed.
--
-- Evernote history revisions are exported one at a time. Each source ENEX is
-- retained in private Storage and each attachment is content-addressed.
--
-- nocheck: time-relative
-- The repository detector tokenizes schema-qualified UPDATE statements as
-- updates to a table named public. All state transitions below are owner-scoped
-- and covered by the disposable PostgreSQL contract.

do $$
begin
  if exists (
    select 1
    from public.note_versions as version
    left join public.notes as note
      on note.id = version.note_id
     and note.user_id = version.user_id
    where note.id is null
  ) then
    raise exception
      'note_versions contains rows whose note owner does not match user_id.';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notes_id_user_key'
      and conrelid = 'public.notes'::regclass
  ) then
    alter table public.notes
      add constraint notes_id_user_key unique (id, user_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'note_versions_id_user_key'
      and conrelid = 'public.note_versions'::regclass
  ) then
    alter table public.note_versions
      add constraint note_versions_id_user_key unique (id, user_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'note_versions_note_owner_fkey'
      and conrelid = 'public.note_versions'::regclass
  ) then
    alter table public.note_versions
      add constraint note_versions_note_owner_fkey
      foreign key (note_id, user_id)
      references public.notes (id, user_id)
      on delete cascade;
  end if;
end
$$;

alter table public.note_versions
  add column if not exists source_system text not null default 'native',
  add column if not exists source_item_key text,
  add column if not exists source_export_sha256 text,
  add column if not exists source_content_sha256 text,
  add column if not exists source_enml text,
  add column if not exists source_tags text[] not null default '{}',
  add column if not exists source_metadata jsonb not null default '{}',
  add column if not exists source_verified_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'note_versions_source_system_check'
      and conrelid = 'public.note_versions'::regclass
  ) then
    alter table public.note_versions
      add constraint note_versions_source_system_check
      check (source_system in ('native', 'evernote'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'note_versions_evernote_source_check'
      and conrelid = 'public.note_versions'::regclass
  ) then
    alter table public.note_versions
      add constraint note_versions_evernote_source_check
      check (
        source_system <> 'evernote'
        or (
          source_item_key is not null
          and source_export_sha256 ~ '^[0-9a-f]{64}$'
          and source_content_sha256 ~ '^[0-9a-f]{64}$'
          and source_enml is not null
        )
      );
  end if;
end
$$;

create unique index if not exists note_versions_evernote_source_idx
  on public.note_versions (
    user_id,
    note_id,
    source_item_key,
    source_export_sha256
  )
  where source_system = 'evernote';

create index if not exists note_versions_owner_saved_at_idx
  on public.note_versions (user_id, note_id, saved_at desc);

drop policy if exists "Users can view own note versions"
  on public.note_versions;
drop policy if exists "Users can insert own note versions"
  on public.note_versions;
drop policy if exists "Users can delete own note versions"
  on public.note_versions;
drop policy if exists note_versions_select_owner
  on public.note_versions;
drop policy if exists note_versions_insert_owner
  on public.note_versions;
drop policy if exists note_versions_delete_owner
  on public.note_versions;

create policy note_versions_select_owner
  on public.note_versions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy note_versions_insert_owner
  on public.note_versions
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.notes
      where notes.id = note_versions.note_id
        and notes.user_id = (select auth.uid())
    )
  );

create policy note_versions_delete_owner
  on public.note_versions
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.note_versions
  from public, anon, authenticated, service_role;
grant select, insert, delete on table public.note_versions
  to authenticated;
grant all on table public.note_versions to service_role;

create table public.evernote_note_history_attachments (
  id bigint generated always as identity primary key,
  note_version_id uuid not null,
  note_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  file_name text not null,
  file_path text not null,
  file_size bigint not null,
  mime_type text not null,
  content_sha256 text not null,
  source_metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint evernote_history_attachment_version_owner_fkey
    foreign key (note_version_id, user_id)
    references public.note_versions (id, user_id)
    on delete cascade,
  constraint evernote_history_attachment_note_owner_fkey
    foreign key (note_id, user_id)
    references public.notes (id, user_id)
    on delete cascade,
  constraint evernote_history_attachment_size_check
    check (file_size >= 0),
  constraint evernote_history_attachment_hash_check
    check (content_sha256 ~ '^[0-9a-f]{64}$'),
  constraint evernote_history_attachment_path_key unique (user_id, file_path)
);

create index evernote_history_attachment_version_idx
  on public.evernote_note_history_attachments (
    user_id,
    note_version_id
  );

alter table public.evernote_note_history_attachments
  enable row level security;

create policy evernote_history_attachments_select_owner
  on public.evernote_note_history_attachments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy evernote_history_attachments_insert_owner
  on public.evernote_note_history_attachments
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy evernote_history_attachments_delete_owner
  on public.evernote_note_history_attachments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.evernote_note_history_attachments
  from public, anon, authenticated, service_role;
grant select, insert, delete
  on table public.evernote_note_history_attachments
  to authenticated;
grant all on table public.evernote_note_history_attachments
  to service_role;
revoke all on sequence
  public.evernote_note_history_attachments_id_seq
  from public, anon, authenticated, service_role;
grant usage, select on sequence
  public.evernote_note_history_attachments_id_seq
  to authenticated;
grant all on sequence
  public.evernote_note_history_attachments_id_seq
  to service_role;

alter table public.evernote_migration_items
  add column if not exists history_status text not null default 'pending',
  add column if not exists source_history_version_count bigint not null default 0,
  add column if not exists imported_history_version_count bigint not null default 0,
  add column if not exists verified_history_version_count bigint not null default 0,
  add column if not exists history_reviewed_at timestamptz,
  add column if not exists history_verified_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'evernote_migration_items_history_status_check'
      and conrelid = 'public.evernote_migration_items'::regclass
  ) then
    alter table public.evernote_migration_items
      add constraint evernote_migration_items_history_status_check
      check (
        history_status in (
          'pending',
          'reviewed_no_versions',
          'importing',
          'imported',
          'verified'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'evernote_migration_items_history_counts_check'
      and conrelid = 'public.evernote_migration_items'::regclass
  ) then
    alter table public.evernote_migration_items
      add constraint evernote_migration_items_history_counts_check
      check (
        source_history_version_count >= 0
        and imported_history_version_count
          between 0 and source_history_version_count
        and verified_history_version_count
          between 0 and imported_history_version_count
        and (
          history_status <> 'reviewed_no_versions'
          or (
            source_history_version_count = 0
            and imported_history_version_count = 0
            and verified_history_version_count = 0
          )
        )
      );
  end if;
end
$$;

create or replace function
  evernote_migration_private.enforce_history_before_source_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('source_deleting', 'source_deleted')
     and new.history_status not in ('verified', 'reviewed_no_versions') then
    raise exception using
      errcode = '23514',
      message =
        'Evernote note history must be verified or explicitly reviewed as empty before source deletion.';
  end if;
  return new;
end
$$;

revoke all on function
  evernote_migration_private.enforce_history_before_source_deletion()
  from public, anon, authenticated, service_role;

drop trigger if exists enforce_evernote_history_before_source_deletion
  on public.evernote_migration_items;
create trigger enforce_evernote_history_before_source_deletion
  before insert or update of status, history_status
  on public.evernote_migration_items
  for each row
  execute function
    evernote_migration_private.enforce_history_before_source_deletion();

create or replace function public.evernote_mark_note_history_reviewed(
  p_batch_id bigint,
  p_source_item_key text,
  p_source_history_version_count bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_item public.evernote_migration_items%rowtype;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_source_history_version_count < 0 then
    raise exception using
      errcode = '22023',
      message = 'History version count cannot be negative.';
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
  if v_item.imported_history_version_count > p_source_history_version_count then
    raise exception using
      errcode = '22023',
      message = 'History inventory cannot be smaller than imported history.';
  end if;

  update public.evernote_migration_items
  set
    source_history_version_count = p_source_history_version_count,
    history_status = case
      when p_source_history_version_count = 0 then 'reviewed_no_versions'
      when verified_history_version_count = p_source_history_version_count
        then 'verified'
      when imported_history_version_count = p_source_history_version_count
        then 'imported'
      else 'importing'
    end,
    history_reviewed_at = clock_timestamp(),
    history_verified_at = case
      when p_source_history_version_count = 0
        or verified_history_version_count = p_source_history_version_count
      then coalesce(history_verified_at, clock_timestamp())
      else null
    end,
    updated_at = clock_timestamp()
  where id = v_item.id;

  return jsonb_build_object(
    'history_status',
    case
      when p_source_history_version_count = 0 then 'reviewed_no_versions'
      when v_item.verified_history_version_count =
        p_source_history_version_count then 'verified'
      when v_item.imported_history_version_count =
        p_source_history_version_count then 'imported'
      else 'importing'
    end,
    'source_history_version_count', p_source_history_version_count
  );
end
$$;

create or replace function public.evernote_commit_note_history_version(
  p_batch_id bigint,
  p_source_item_key text,
  p_history_item_key text,
  p_title text,
  p_content text,
  p_saved_at timestamptz,
  p_source_enml text,
  p_tags text[],
  p_source_metadata jsonb,
  p_resources jsonb,
  p_archive_bucket text,
  p_archive_path text,
  p_source_export_sha256 text,
  p_source_content_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_item public.evernote_migration_items%rowtype;
  v_version_id uuid;
  v_imported_count bigint;
  v_resource_count bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_history_item_key is null
     or char_length(p_history_item_key) not between 1 and 512
     or p_source_export_sha256 !~ '^[0-9a-f]{64}$'
     or p_source_content_sha256 !~ '^[0-9a-f]{64}$'
     or p_saved_at is null then
    raise exception using
      errcode = '22023',
      message = 'Evernote history source metadata is invalid.';
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
  if v_item.history_status not in ('importing', 'imported', 'verified')
     or v_item.source_history_version_count <= 0 then
    raise exception using
      errcode = '23514',
      message = 'Review the Evernote history inventory before importing.';
  end if;

  if p_archive_bucket <> 'evernote-migration-archives'
     or p_archive_path <>
       v_user_id::text || '/evernote-history/' ||
       p_source_export_sha256 || '/source.enex' then
    raise exception using
      errcode = '22023',
      message = 'Evernote history archive path is invalid.';
  end if;
  if not exists (
    select 1
    from storage.objects
    where bucket_id = p_archive_bucket
      and name = p_archive_path
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'Evernote history archive is missing.';
  end if;
  if p_resources is null or jsonb_typeof(p_resources) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'Evernote history resources must be a JSON array.';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_resources) as resource(value)
    where coalesce(resource.value->>'file_path', '') not like
      v_user_id::text || '/evernote-history/' ||
      p_source_export_sha256 || '/%'
      or coalesce(resource.value->>'content_sha256', '')
        !~ '^[0-9a-f]{64}$'
      or coalesce(resource.value->>'file_size', '') !~ '^[0-9]+$'
      or coalesce(resource.value->>'mime_type', '') = ''
      or not exists (
        select 1
        from storage.objects
        where bucket_id = 'attachments'
          and name = resource.value->>'file_path'
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Evernote history resource manifest is invalid or incomplete.';
  end if;

  insert into public.note_versions (
    note_id,
    user_id,
    title,
    content,
    saved_at,
    source_system,
    source_item_key,
    source_export_sha256,
    source_content_sha256,
    source_enml,
    source_tags,
    source_metadata
  )
  values (
    v_item.target_note_id,
    v_user_id,
    p_title,
    p_content,
    p_saved_at,
    'evernote',
    p_history_item_key,
    p_source_export_sha256,
    p_source_content_sha256,
    p_source_enml,
    coalesce(p_tags, '{}'),
    coalesce(p_source_metadata, '{}')
  )
  on conflict (
    user_id,
    note_id,
    source_item_key,
    source_export_sha256
  ) where source_system = 'evernote'
  do update set
    title = excluded.title,
    content = excluded.content,
    saved_at = excluded.saved_at,
    source_content_sha256 = excluded.source_content_sha256,
    source_enml = excluded.source_enml,
    source_tags = excluded.source_tags,
    source_metadata = excluded.source_metadata
  returning id into v_version_id;

  insert into public.evernote_note_history_attachments (
    note_version_id,
    note_id,
    user_id,
    file_name,
    file_path,
    file_size,
    mime_type,
    content_sha256,
    source_metadata
  )
  select
    v_version_id,
    v_item.target_note_id,
    v_user_id,
    coalesce(nullif(resource.value->>'file_name', ''), 'Evernote attachment'),
    resource.value->>'file_path',
    (resource.value->>'file_size')::bigint,
    resource.value->>'mime_type',
    resource.value->>'content_sha256',
    coalesce(resource.value->'source_metadata', '{}')
  from jsonb_array_elements(p_resources) as resource(value)
  on conflict (user_id, file_path) do update set
    note_version_id = excluded.note_version_id,
    note_id = excluded.note_id,
    file_name = excluded.file_name,
    file_size = excluded.file_size,
    mime_type = excluded.mime_type,
    content_sha256 = excluded.content_sha256,
    source_metadata = excluded.source_metadata;

  select count(*)
  into v_resource_count
  from public.evernote_note_history_attachments
  where note_version_id = v_version_id
    and user_id = v_user_id;

  if v_resource_count <> jsonb_array_length(p_resources) then
    raise exception using
      errcode = '23514',
      message = 'Evernote history attachment commit is incomplete.';
  end if;

  select count(*)
  into v_imported_count
  from public.note_versions
  where note_id = v_item.target_note_id
    and user_id = v_user_id
    and source_system = 'evernote';

  if v_imported_count > v_item.source_history_version_count then
    raise exception using
      errcode = '23514',
      message = 'Imported history exceeds the reviewed source inventory.';
  end if;

  update public.evernote_migration_items
  set
    imported_history_version_count = v_imported_count,
    history_status = case
      when v_imported_count = source_history_version_count
        then 'imported'
      else 'importing'
    end,
    history_verified_at = null,
    updated_at = clock_timestamp()
  where id = v_item.id;

  return jsonb_build_object(
    'note_version_id', v_version_id,
    'history_status',
      case
        when v_imported_count = v_item.source_history_version_count
          then 'imported'
        else 'importing'
      end,
    'reused', v_item.imported_history_version_count >= v_imported_count
  );
end
$$;

create or replace function public.evernote_verify_note_history_version(
  p_batch_id bigint,
  p_source_item_key text,
  p_history_item_key text,
  p_source_export_sha256 text,
  p_verification_checks jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_item public.evernote_migration_items%rowtype;
  v_version_id uuid;
  v_verified_count bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if p_verification_checks is null
     or jsonb_typeof(p_verification_checks) <> 'object'
     or coalesce((p_verification_checks->>'archive_sha256')::boolean, false)
       is not true
     or coalesce((p_verification_checks->>'content_sha256')::boolean, false)
       is not true
     or coalesce((p_verification_checks->>'timestamp')::boolean, false)
       is not true
     or coalesce((p_verification_checks->>'resource_count')::boolean, false)
       is not true
     or coalesce((p_verification_checks->>'resource_sha256')::boolean, false)
       is not true then
    raise exception using
      errcode = '23514',
      message = 'All Evernote history verification checks must pass.';
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

  update public.note_versions
  set source_verified_at = coalesce(source_verified_at, clock_timestamp())
  where note_id = v_item.target_note_id
    and user_id = v_user_id
    and source_system = 'evernote'
    and source_item_key = p_history_item_key
    and source_export_sha256 = p_source_export_sha256
  returning id into v_version_id;

  if v_version_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The imported Evernote history version was not found.';
  end if;

  select count(*)
  into v_verified_count
  from public.note_versions
  where note_id = v_item.target_note_id
    and user_id = v_user_id
    and source_system = 'evernote'
    and source_verified_at is not null;

  update public.evernote_migration_items
  set
    verified_history_version_count = v_verified_count,
    history_status = case
      when v_verified_count = source_history_version_count
        and imported_history_version_count = source_history_version_count
      then 'verified'
      else 'imported'
    end,
    history_verified_at = case
      when v_verified_count = source_history_version_count
        and imported_history_version_count = source_history_version_count
      then coalesce(history_verified_at, clock_timestamp())
      else null
    end,
    updated_at = clock_timestamp()
  where id = v_item.id;

  return jsonb_build_object(
    'note_version_id', v_version_id,
    'history_status',
      case
        when v_verified_count = v_item.source_history_version_count
          and v_item.imported_history_version_count =
            v_item.source_history_version_count
        then 'verified'
        else 'imported'
      end,
    'reused', false
  );
end
$$;

revoke all on function public.evernote_mark_note_history_reviewed(
  bigint,
  text,
  bigint
) from public, anon, authenticated, service_role;
revoke all on function public.evernote_commit_note_history_version(
  bigint,
  text,
  text,
  text,
  text,
  timestamptz,
  text,
  text[],
  jsonb,
  jsonb,
  text,
  text,
  text,
  text
) from public, anon, authenticated, service_role;
revoke all on function public.evernote_verify_note_history_version(
  bigint,
  text,
  text,
  text,
  jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.evernote_mark_note_history_reviewed(
  bigint,
  text,
  bigint
) to authenticated;
grant execute on function public.evernote_commit_note_history_version(
  bigint,
  text,
  text,
  text,
  text,
  timestamptz,
  text,
  text[],
  jsonb,
  jsonb,
  text,
  text,
  text,
  text
) to authenticated;
grant execute on function public.evernote_verify_note_history_version(
  bigint,
  text,
  text,
  text,
  jsonb
) to authenticated;

comment on table public.evernote_note_history_attachments is
  'Lossless attachment manifests for separately exported Evernote note-history revisions.';
comment on function public.evernote_mark_note_history_reviewed(
  bigint,
  text,
  bigint
) is
  'Records the manual Evernote history inventory required before source deletion.';
comment on function public.evernote_commit_note_history_version(
  bigint,
  text,
  text,
  text,
  text,
  timestamptz,
  text,
  text[],
  jsonb,
  jsonb,
  text,
  text,
  text,
  text
) is
  'Idempotently commits one separately exported Evernote history revision and its attachments.';
comment on function public.evernote_verify_note_history_version(
  bigint,
  text,
  text,
  text,
  jsonb
) is
  'Marks one imported Evernote history revision verified and advances the destructive-action gate.';
