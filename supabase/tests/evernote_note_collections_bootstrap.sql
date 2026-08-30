-- Minimal Supabase-shaped fixture for Evernote hierarchy contract tests.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;

create schema auth;
create table auth.users (
  id uuid primary key,
  email text
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claim.sub', true),
    ''
  )::uuid
$$;

grant usage on schema auth to authenticated, service_role;
grant execute on function auth.uid() to authenticated, service_role;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $
  select jsonb_build_object(
    'sub',
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    'email',
    nullif(current_setting('request.jwt.claim.email', true), '')
  )
$;

grant execute on function auth.jwt() to authenticated, service_role;

create table public.notes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  tags text[] not null default '{}',
  is_archived boolean not null default false,
  is_pinned boolean not null default false,
  reminder_date timestamptz
);

create index notes_user_id_idx on public.notes (user_id);
alter table public.notes enable row level security;

create policy notes_select_owner
  on public.notes for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notes_insert_owner
  on public.notes for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notes_update_owner
  on public.notes for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy notes_delete_owner
  on public.notes for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.notes to authenticated;
grant usage, select on sequence public.notes_id_seq to authenticated;
grant all on public.notes to service_role;
grant all on sequence public.notes_id_seq to service_role;

create table public.evernote_migration_items (
  id bigint generated always as identity primary key,
  batch_id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  source_item_key text not null,
  target_note_id bigint references public.notes (id) on delete set null,
  source_metadata jsonb not null default '{}',
  status text not null default 'previewed',
  updated_at timestamptz not null default now(),
  unique (batch_id, user_id, source_item_key)
);

create index evernote_migration_items_user_idx
  on public.evernote_migration_items (user_id);
alter table public.evernote_migration_items enable row level security;

create policy evernote_items_select_owner
  on public.evernote_migration_items for select to authenticated
  using ((select auth.uid()) = user_id);
create policy evernote_items_insert_owner
  on public.evernote_migration_items for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy evernote_items_update_owner
  on public.evernote_migration_items for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.evernote_migration_items
  to authenticated;
grant usage, select on sequence
  public.evernote_migration_items_id_seq to authenticated;
grant all on public.evernote_migration_items to service_role;
grant all on sequence public.evernote_migration_items_id_seq
  to service_role;

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
  v_note_id bigint;
begin
  select target_note_id
  into v_note_id
  from public.evernote_migration_items
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key;

  if v_note_id is not null then
    return jsonb_build_object(
      'note_id', v_note_id,
      'status', 'imported',
      'reused', true
    );
  end if;

  insert into public.notes (
    user_id,
    title,
    content,
    created_at,
    updated_at,
    tags
  )
  values (
    v_user_id,
    p_title,
    p_content,
    coalesce(p_source_created_at, now()),
    coalesce(p_source_updated_at, p_source_created_at, now()),
    coalesce(p_tags, '{}')
  )
  returning id into v_note_id;

  insert into public.evernote_migration_items (
    batch_id,
    user_id,
    source_item_key,
    target_note_id,
    source_metadata,
    status
  )
  values (
    p_batch_id,
    v_user_id,
    p_source_item_key,
    v_note_id,
    coalesce(p_source_metadata, '{}'),
    'imported'
  );

  return jsonb_build_object(
    'note_id', v_note_id,
    'status', 'imported',
    'reused', false
  );
end
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
  v_note_id bigint;
begin
  update public.evernote_migration_items
  set
    status = 'verified',
    updated_at = clock_timestamp()
  where batch_id = p_batch_id
    and user_id = v_user_id
    and source_item_key = p_source_item_key
  returning target_note_id into v_note_id;

  if v_note_id is null then
    raise exception 'Evernote item not found.';
  end if;

  return jsonb_build_object(
    'note_id', v_note_id,
    'status', 'verified',
    'reused', false
  );
end
$$;

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


-- Supabase Storage-shaped fixture required by the history contract.
create schema storage;
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null,
  owner_id uuid,
  metadata jsonb not null default '{}',
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;

create policy storage_objects_select_owner
  on storage.objects for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy storage_objects_insert_owner
  on storage.objects for insert to authenticated
  with check ((select auth.uid()) = owner_id);

grant usage on schema storage to authenticated, service_role;
grant select, insert on storage.objects to authenticated;
grant all on storage.objects to service_role;

-- Shape of the native note history before the Evernote extension migration.
create table public.note_versions (
  id uuid primary key default gen_random_uuid(),
  note_id bigint not null references public.notes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default '',
  content text not null default '',
  saved_at timestamptz not null default now()
);
alter table public.note_versions enable row level security;

create policy "Users can view own note versions"
  on public.note_versions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert own note versions"
  on public.note_versions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own note versions"
  on public.note_versions for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, delete on public.note_versions to authenticated;
grant all on public.note_versions to service_role;
create index note_versions_note_id_saved_at_idx
  on public.note_versions (note_id, saved_at desc);
