-- Store only a local Obsidian manifest's digest, aggregate safety counts, and
-- allowlisted note/attachment structure. Note bodies, excluded paths, and
-- credential material never belong in these tables.

create table public.notion_migration_vault_manifests (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  user_id uuid not null default auth.uid(),
  schema_version integer not null check (schema_version = 1),
  vault_name text not null check (char_length(vault_name) between 1 and 200),
  source_file_name text not null check (
    char_length(source_file_name) between 1 and 255
    and position('/' in source_file_name) = 0
    and position(chr(92) in source_file_name) = 0
  ),
  source_manifest_sha256 text not null check (
    source_manifest_sha256 ~ '^[0-9a-f]{64}$'
  ),
  file_count integer not null check (file_count >= 0),
  auto_stage_count integer not null check (auto_stage_count >= 0),
  review_required_count integer not null check (review_required_count >= 0),
  excluded_count integer not null check (excluded_count >= 0),
  credential_candidate_count integer not null check (
    credential_candidate_count >= 0
    and credential_candidate_count <= excluded_count
  ),
  unresolved_wikilink_occurrences bigint not null default 0 check (
    unresolved_wikilink_occurrences >= 0
  ),
  status text not null default 'staging' check (
    status in ('staging', 'staged', 'failed')
  ),
  staged_entry_count integer not null default 0 check (
    staged_entry_count >= 0
    and staged_entry_count <= auto_stage_count + review_required_count
  ),
  last_error text check (
    last_error is null or char_length(last_error) <= 2000
  ),
  staged_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, batch_id, user_id),
  unique (batch_id, source_manifest_sha256),
  foreign key (batch_id, user_id)
    references public.notion_migration_batches(id, user_id)
    on delete cascade,
  check (file_count = auto_stage_count + review_required_count + excluded_count),
  check (
    status <> 'staged'
    or (
      staged_at is not null
      and staged_entry_count = auto_stage_count + review_required_count
    )
  )
);

create table public.notion_migration_vault_entries (
  id uuid primary key default gen_random_uuid(),
  manifest_id uuid not null,
  batch_id uuid not null,
  user_id uuid not null default auth.uid(),
  relative_path text not null check (
    char_length(relative_path) between 1 and 4000
    and relative_path !~ '(^/|(^|/)\.\.(/|$)|^[a-zA-Z]:)'
    and position(chr(92) in relative_path) = 0
  ),
  category text not null check (category in ('note', 'attachment')),
  migration_action text not null check (
    migration_action in ('auto_stage', 'review_required')
  ),
  size_bytes bigint not null check (size_bytes >= 0),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  structure_metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(structure_metadata) = 'object'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (manifest_id, relative_path),
  check (
    (
      category = 'note'
      and structure_metadata - array[
        'frontmatter_present',
        'property_keys',
        'wikilinks',
        'external_link_count',
        'callout_types',
        'task_count',
        'completed_task_count'
      ]::text[] = '{}'::jsonb
    )
    or (
      category = 'attachment'
      and structure_metadata - array['referenced_by']::text[] = '{}'::jsonb
    )
  ),
  foreign key (manifest_id, batch_id, user_id)
    references public.notion_migration_vault_manifests(id, batch_id, user_id)
    on delete cascade
);

create index notion_migration_vault_manifests_owner_batch_idx
  on public.notion_migration_vault_manifests (user_id, batch_id, created_at desc);
create index notion_migration_vault_manifests_batch_owner_idx
  on public.notion_migration_vault_manifests (batch_id, user_id);
create index notion_migration_vault_entries_owner_manifest_idx
  on public.notion_migration_vault_entries (
    user_id, manifest_id, migration_action
  );

alter table public.notion_migration_vault_manifests enable row level security;
alter table public.notion_migration_vault_entries enable row level security;

create policy notion_migration_vault_manifests_select_own
  on public.notion_migration_vault_manifests
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_vault_manifests_insert_own
  on public.notion_migration_vault_manifests
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_vault_manifests_update_own
  on public.notion_migration_vault_manifests
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notion_migration_vault_entries_select_own
  on public.notion_migration_vault_entries
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_vault_entries_insert_own
  on public.notion_migration_vault_entries
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_vault_entries_update_own
  on public.notion_migration_vault_entries
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.notion_migration_vault_manifests
  from public, anon, authenticated;
revoke all on table public.notion_migration_vault_entries
  from public, anon, authenticated;
grant select, insert, update
  on table public.notion_migration_vault_manifests to authenticated;
grant select, insert, update
  on table public.notion_migration_vault_entries to authenticated;
grant select, insert, update, delete
  on table public.notion_migration_vault_manifests to service_role;
grant select, insert, update, delete
  on table public.notion_migration_vault_entries to service_role;

create trigger notion_migration_vault_manifests_touch_updated_at
  before update on public.notion_migration_vault_manifests
  for each row execute function public.notion_migration_touch_updated_at();
create trigger notion_migration_vault_entries_touch_updated_at
  before update on public.notion_migration_vault_entries
  for each row execute function public.notion_migration_touch_updated_at();
