create table public.evernote_migration_batches (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_export_sha256 text not null,
  source_file_name text not null,
  status text not null default 'previewed',
  source_note_count bigint not null,
  source_resource_count bigint not null default 0,
  imported_note_count bigint not null default 0,
  verified_note_count bigint not null default 0,
  source_deleted_note_count bigint not null default 0,
  verification_summary jsonb not null default '{}'::jsonb,
  last_error text,
  imported_at timestamptz,
  verified_at timestamptz,
  source_deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evernote_migration_batches_export_hash_format_check
    check (source_export_sha256 ~ '^[0-9a-f]{64}$'),
  constraint evernote_migration_batches_status_check
    check (status in (
      'previewed',
      'importing',
      'imported',
      'verifying',
      'verified',
      'source_deleting',
      'source_deleted',
      'failed'
    )),
  constraint evernote_migration_batches_counts_check
    check (
      source_note_count >= 0
      and source_resource_count >= 0
      and imported_note_count between 0 and source_note_count
      and verified_note_count between 0 and imported_note_count
      and source_deleted_note_count between 0 and verified_note_count
    ),
  constraint evernote_migration_batches_user_export_unique
    unique (user_id, source_export_sha256),
  constraint evernote_migration_batches_id_user_unique
    unique (id, user_id)
);

create table public.evernote_migration_items (
  id bigint generated always as identity primary key,
  batch_id bigint not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_item_key text not null,
  source_note_id text,
  source_content_sha256 text,
  source_resource_count bigint not null default 0,
  target_note_id bigint,
  status text not null default 'previewed',
  verification_checks jsonb not null default '{}'::jsonb,
  last_error text,
  imported_at timestamptz,
  verified_at timestamptz,
  source_deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evernote_migration_items_batch_owner_fkey
    foreign key (batch_id, user_id)
    references public.evernote_migration_batches(id, user_id)
    on delete cascade,
  constraint evernote_migration_items_source_item_key_check
    check (char_length(source_item_key) between 1 and 512),
  constraint evernote_migration_items_content_hash_format_check
    check (
      source_content_sha256 is null
      or source_content_sha256 ~ '^[0-9a-f]{64}$'
    ),
  constraint evernote_migration_items_resource_count_check
    check (source_resource_count >= 0),
  constraint evernote_migration_items_status_check
    check (status in (
      'previewed',
      'importing',
      'imported',
      'verifying',
      'verified',
      'source_deleting',
      'source_deleted',
      'failed'
    )),
  constraint evernote_migration_items_batch_source_unique
    unique (batch_id, source_item_key)
);

create index evernote_migration_batches_user_updated_idx
  on public.evernote_migration_batches (user_id, updated_at desc);

create index evernote_migration_items_user_batch_status_idx
  on public.evernote_migration_items (user_id, batch_id, status);

alter table public.evernote_migration_batches enable row level security;
alter table public.evernote_migration_items enable row level security;

create policy "evernote migration batch owners can read"
  on public.evernote_migration_batches
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "evernote migration batch owners can insert"
  on public.evernote_migration_batches
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "evernote migration batch owners can update"
  on public.evernote_migration_batches
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "evernote migration item owners can read"
  on public.evernote_migration_items
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "evernote migration item owners can insert"
  on public.evernote_migration_items
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "evernote migration item owners can update"
  on public.evernote_migration_items
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.evernote_migration_batches
  from anon, authenticated, service_role;
revoke all on table public.evernote_migration_items
  from anon, authenticated, service_role;

grant select, insert, update
  on table public.evernote_migration_batches
  to authenticated;
grant select, insert, update
  on table public.evernote_migration_items
  to authenticated;

grant select, insert, update, delete
  on table public.evernote_migration_batches
  to service_role;
grant select, insert, update, delete
  on table public.evernote_migration_items
  to service_role;

grant usage, select
  on sequence public.evernote_migration_batches_id_seq
  to authenticated, service_role;
grant usage, select
  on sequence public.evernote_migration_items_id_seq
  to authenticated, service_role;
