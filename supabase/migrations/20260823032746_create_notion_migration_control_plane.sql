-- Track a Notion workspace migration without exposing workspace contents to
-- other users. Source deletion is intentionally gated by seven verification
-- checks and a separately recorded owner authorization timestamp.

create table public.notion_migration_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  workspace_id text not null check (char_length(workspace_id) between 1 and 200),
  workspace_name text not null check (
    char_length(workspace_name) between 1 and 200
  ),
  name text not null check (char_length(name) between 1 and 200),
  status text not null default 'inventory' check (
    status in (
      'inventory',
      'migrating',
      'verifying',
      'awaiting_source_deletion',
      'completed',
      'paused',
      'failed'
    )
  ),
  source_export_sha256 text check (
    source_export_sha256 is null
    or source_export_sha256 ~ '^[0-9a-f]{64}$'
  ),
  source_export_storage_path text check (
    source_export_storage_path is null
    or char_length(source_export_storage_path) between 1 and 1024
  ),
  started_at timestamptz,
  completed_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create unique index notion_migration_one_active_workspace_idx
  on public.notion_migration_batches (user_id, workspace_id)
  where archived_at is null and status <> 'completed';

create table public.notion_migration_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  user_id uuid not null default auth.uid(),
  source_id text not null check (char_length(source_id) between 1 and 512),
  parent_source_id text check (
    parent_source_id is null
    or char_length(parent_source_id) between 1 and 512
  ),
  source_kind text not null check (
    source_kind in (
      'workspace',
      'teamspace',
      'page',
      'database',
      'data_source',
      'view',
      'block',
      'comment',
      'attachment',
      'automation',
      'form',
      'user'
    )
  ),
  title text not null default '' check (char_length(title) <= 1000),
  source_path text not null default '' check (
    char_length(source_path) <= 4000
  ),
  status text not null default 'inventoried' check (
    status in (
      'inventoried',
      'queued',
      'exporting',
      'imported',
      'verifying',
      'verified',
      'ready_for_source_deletion',
      'source_deleted',
      'failed',
      'skipped'
    )
  ),
  destination_kind text check (
    destination_kind is null
    or char_length(destination_kind) between 1 and 100
  ),
  destination_id text check (
    destination_id is null
    or char_length(destination_id) between 1 and 512
  ),
  source_hash text check (
    source_hash is null or source_hash ~ '^[0-9a-f]{64}$'
  ),
  destination_hash text check (
    destination_hash is null or destination_hash ~ '^[0-9a-f]{64}$'
  ),
  source_updated_at timestamptz,
  imported_at timestamptz,
  verified_at timestamptz,
  deletion_authorized_at timestamptz,
  source_deleted_at timestamptz,
  last_error text check (last_error is null or char_length(last_error) <= 4000),
  metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(metadata) = 'object'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (batch_id, source_id),
  foreign key (batch_id, user_id)
    references public.notion_migration_batches(id, user_id)
    on delete cascade
);

create index notion_migration_items_batch_status_idx
  on public.notion_migration_items (batch_id, status);
create index notion_migration_items_parent_idx
  on public.notion_migration_items (batch_id, parent_source_id);

create table public.notion_migration_checks (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null,
  user_id uuid not null default auth.uid(),
  check_key text not null check (
    check_key in (
      'backup',
      'content',
      'hierarchy',
      'properties',
      'attachments',
      'comments',
      'permissions'
    )
  ),
  status text not null default 'pending' check (
    status in ('pending', 'passed', 'failed')
  ),
  source_count bigint check (source_count is null or source_count >= 0),
  destination_count bigint check (
    destination_count is null or destination_count >= 0
  ),
  source_hash text check (
    source_hash is null or source_hash ~ '^[0-9a-f]{64}$'
  ),
  destination_hash text check (
    destination_hash is null or destination_hash ~ '^[0-9a-f]{64}$'
  ),
  checked_at timestamptz,
  evidence_summary text not null default '' check (
    char_length(evidence_summary) <= 4000
    and (status <> 'passed' or char_length(trim(evidence_summary)) > 0)
    and (status <> 'passed' or checked_at is not null)
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, check_key),
  foreign key (item_id, user_id)
    references public.notion_migration_items(id, user_id)
    on delete cascade
);

create index notion_migration_checks_item_status_idx
  on public.notion_migration_checks (item_id, status);

create table public.notion_migration_capabilities (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  user_id uuid not null default auth.uid(),
  capability_key text not null check (
    char_length(capability_key) between 1 and 100
  ),
  name text not null check (char_length(name) between 1 and 200),
  notion_scope text not null check (
    char_length(notion_scope) between 1 and 1000
  ),
  site_routes text[] not null default '{}'::text[],
  is_required boolean not null default true,
  status text not null default 'inventory' check (
    status in (
      'inventory',
      'planned',
      'implemented',
      'verifying',
      'verified',
      'gap',
      'blocked'
    )
  ),
  evidence_summary text not null default '' check (
    char_length(evidence_summary) <= 4000
    and (
      status <> 'verified'
      or (
        char_length(trim(evidence_summary)) > 0
        and verified_at is not null
      )
    )
  ),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (batch_id, capability_key),
  foreign key (batch_id, user_id)
    references public.notion_migration_batches(id, user_id)
    on delete cascade
);

create index notion_migration_capabilities_batch_status_idx
  on public.notion_migration_capabilities (batch_id, status);
create index notion_migration_capabilities_owner_batch_idx
  on public.notion_migration_capabilities (user_id, batch_id);

create table public.notion_migration_wbs_staging (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  user_id uuid not null,
  source_page_id text not null check (
    char_length(source_page_id) between 1 and 512
  ),
  task_id text not null default '' check (char_length(task_id) <= 512),
  duplicate_ordinal integer not null default 1 check (
    duplicate_ordinal >= 1
  ),
  title text not null default '' check (char_length(title) <= 2000),
  instance text not null default '' check (char_length(instance) <= 100),
  status text not null default '' check (char_length(status) <= 100),
  progress numeric not null default 0,
  deadline date,
  source_updated_at timestamptz,
  source_last_edited_at timestamptz,
  source_payload jsonb not null check (jsonb_typeof(source_payload) = 'object'),
  stage_run_id uuid not null,
  is_current boolean not null default true,
  staged_at timestamptz not null default now(),
  unique (id, user_id),
  unique (batch_id, source_page_id),
  foreign key (batch_id, user_id)
    references public.notion_migration_batches(id, user_id)
    on delete cascade
);

create index notion_migration_wbs_staging_current_idx
  on public.notion_migration_wbs_staging (batch_id, is_current, task_id);
create index notion_migration_wbs_staging_owner_batch_idx
  on public.notion_migration_wbs_staging (user_id, batch_id);

alter table public.notion_migration_batches enable row level security;
alter table public.notion_migration_items enable row level security;
alter table public.notion_migration_checks enable row level security;
alter table public.notion_migration_capabilities enable row level security;
alter table public.notion_migration_wbs_staging enable row level security;

create policy notion_migration_batches_select_own
  on public.notion_migration_batches
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_batches_insert_own
  on public.notion_migration_batches
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_batches_update_own
  on public.notion_migration_batches
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notion_migration_items_select_own
  on public.notion_migration_items
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_items_insert_own
  on public.notion_migration_items
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_items_update_own
  on public.notion_migration_items
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notion_migration_checks_select_own
  on public.notion_migration_checks
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_checks_insert_own
  on public.notion_migration_checks
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_checks_update_own
  on public.notion_migration_checks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notion_migration_capabilities_select_own
  on public.notion_migration_capabilities
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy notion_migration_capabilities_insert_own
  on public.notion_migration_capabilities
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy notion_migration_capabilities_update_own
  on public.notion_migration_capabilities
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notion_migration_wbs_staging_select_own
  on public.notion_migration_wbs_staging
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.notion_migration_batches from anon, authenticated;
revoke all on table public.notion_migration_items from anon, authenticated;
revoke all on table public.notion_migration_checks from anon, authenticated;
revoke all on table public.notion_migration_capabilities from anon, authenticated;
revoke all on table public.notion_migration_wbs_staging
  from anon, authenticated;
grant select, insert, update on table public.notion_migration_batches
  to authenticated;
grant select, insert, update on table public.notion_migration_items
  to authenticated;
grant select, insert, update on table public.notion_migration_checks
  to authenticated;
grant select, insert, update on table public.notion_migration_capabilities
  to authenticated;
grant select on table public.notion_migration_wbs_staging to authenticated;
grant select, insert, update, delete on table public.notion_migration_batches
  to service_role;
grant select, insert, update, delete on table public.notion_migration_items
  to service_role;
grant select, insert, update, delete on table public.notion_migration_checks
  to service_role;
grant select, insert, update, delete
  on table public.notion_migration_capabilities to service_role;
grant select, insert, update, delete
  on table public.notion_migration_wbs_staging to service_role;

create or replace function public.notion_migration_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger notion_migration_batches_touch_updated_at
  before update on public.notion_migration_batches
  for each row execute function public.notion_migration_touch_updated_at();
create trigger notion_migration_items_touch_updated_at
  before update on public.notion_migration_items
  for each row execute function public.notion_migration_touch_updated_at();
create trigger notion_migration_checks_touch_updated_at
  before update on public.notion_migration_checks
  for each row execute function public.notion_migration_touch_updated_at();
create trigger notion_migration_capabilities_touch_updated_at
  before update on public.notion_migration_capabilities
  for each row execute function public.notion_migration_touch_updated_at();

create or replace function public.notion_migration_seed_capabilities()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.notion_migration_capabilities (
    batch_id,
    user_id,
    capability_key,
    name,
    notion_scope,
    site_routes
  )
  values
    (
      new.id, new.user_id, 'page_tree_blocks', 'ページ階層・ブロック',
      '階層ページ、同期ブロック、コールアウト、埋め込み、リンクドページ',
      array['/notes', '/wiki-database']
    ),
    (
      new.id, new.user_id, 'rich_text_embeds', 'リッチテキスト・埋め込み',
      '書式、数式、コード、ブックマーク、動画、音声、外部埋め込み',
      array['/notes', '/asset-management']
    ),
    (
      new.id, new.user_id, 'page_history_trash', '履歴・復元・ゴミ箱',
      'ページ履歴、変更追跡、削除済みデータの復元、保持期間',
      array['/notes', '/data-backup']
    ),
    (
      new.id, new.user_id, 'wiki_verified_pages', 'Wiki・検証済みページ',
      'Wikiホーム、所有者、検証期限、ページ認証',
      array['/wiki-database', '/knowledge-base']
    ),
    (
      new.id, new.user_id, 'database_data_sources', 'データベース・データソース',
      '単一・複数データソース、リンクドDB、行ページ、データソース切替',
      array['/table-data', '/spreadsheet-database']
    ),
    (
      new.id, new.user_id, 'database_properties_relations_formulas',
      'プロパティ・リレーション・数式',
      '全プロパティ型、リレーション、ロールアップ、数式、ユニークID',
      array['/table-data', '/spreadsheet-database']
    ),
    (
      new.id, new.user_id, 'table_list_gallery_views',
      'テーブル・リスト・ギャラリー',
      'フィルター、並び替え、グループ、表示項目、保存済みビュー',
      array['/table-data']
    ),
    (
      new.id, new.user_id, 'board_calendar_timeline_views',
      'ボード・カレンダー・タイムライン',
      'ボード、カレンダー、タイムライン、依存関係、日付範囲',
      array['/kanban', '/calendar-events', '/gantt-timeline']
    ),
    (
      new.id, new.user_id, 'chart_dashboard_map_feed_views',
      'チャート・ダッシュボード・マップ・フィード',
      'チャート、ダッシュボード、地図、フィードとビュー固有設定',
      array['/personal-dashboard', '/activity-feed']
    ),
    (
      new.id, new.user_id, 'projects_tasks_sprints',
      'プロジェクト・タスク・スプリント',
      'サブタスク、依存関係、マイルストーン、スプリント、進捗集計',
      array['/kanban', '/project-gantt', '/user-tasks']
    ),
    (
      new.id, new.user_id, 'templates', 'テンプレート',
      'ページ・DBテンプレート、繰り返しテンプレート、テンプレート共有',
      array['/templates', '/workflow-templates']
    ),
    (
      new.id, new.user_id, 'forms', 'フォーム',
      '公開・限定フォーム、条件分岐、回答DB、フォーム分析',
      array['/form-builder', '/poll-survey']
    ),
    (
      new.id, new.user_id, 'comments_mentions_notifications',
      'コメント・メンション・通知',
      'ページ・ブロックコメント、@メンション、フォロー、受信箱、通知設定',
      array['/note-comments', '/notifications']
    ),
    (
      new.id, new.user_id, 'realtime_collaboration_presence',
      'リアルタイム共同編集',
      '同時編集、カーソル・プレゼンス、競合解決、チームチャット',
      array['/team-workspace', '/team-chat']
    ),
    (
      new.id, new.user_id, 'sharing_permissions_guests_teamspaces',
      '共有・権限・ゲスト・チームスペース',
      '所有者、メンバー、ゲスト、グループ、ページ権限、チームスペース',
      array['/team-workspace', '/access-control']
    ),
    (
      new.id, new.user_id, 'search_backlinks', '検索・バックリンク',
      '全文検索、絞り込み、最近のページ、バックリンク、関連ページ',
      array['/semantic-search', '/knowledge-graph']
    ),
    (
      new.id, new.user_id, 'files_media', 'ファイル・メディア',
      '添付、プレビュー、容量制限、画像・動画・音声、外部ファイル',
      array['/asset-management', '/import']
    ),
    (
      new.id, new.user_id, 'import_export_backup',
      'インポート・エクスポート・バックアップ',
      'HTML・Markdown・CSV・PDFの入出力、全体バックアップ、復元検証',
      array['/import', '/analytics-export', '/data-backup']
    ),
    (
      new.id, new.user_id, 'offline_mobile', 'オフライン・モバイル',
      'オフライン閲覧・編集、再同期、モバイル操作、競合時の保全',
      array['/offline-secure-mode']
    ),
    (
      new.id, new.user_id, 'automations_buttons_webhooks',
      'オートメーション・ボタン・Webhook',
      'DBオートメーション、ボタン、定期実行、Webhook、実行履歴',
      array['/workflow-automation', '/ai-workflow-automation']
    ),
    (
      new.id, new.user_id, 'integrations_api_mcp', '外部連携・API・MCP',
      '公開API、OAuth連携、インテグレーション権限、Webhook、MCP',
      array['/api-playground', '/mcp-file-search']
    ),
    (
      new.id, new.user_id, 'public_sites_domains_seo',
      '公開サイト・独自ドメイン・SEO',
      '公開ページ、サイトナビ、独自ドメイン、SEO、アクセス制御',
      array['/public-memos', '/dns-domain-manager', '/sitemap-analytics']
    ),
    (
      new.id, new.user_id, 'ai_writing_database', 'AI文章・DB支援',
      '作成、要約、翻訳、校正、AIプロパティ、タグ・入力補助',
      array['/ai-writing-assistant', '/ai-summarizer', '/ai-suggest-tags']
    ),
    (
      new.id, new.user_id, 'ai_agent_search_research',
      'AIエージェント・横断検索・調査',
      'Notion Agent、Enterprise Search、Research Mode、コネクター検索',
      array['/my-ai-agent', '/ai-search', '/semantic-search']
    ),
    (
      new.id, new.user_id, 'meeting_notes_transcription',
      '会議ノート・文字起こし',
      '会議音声、文字起こし、要約、アクション項目、参加者同意',
      array['/video-meeting', '/voice-memo']
    ),
    (
      new.id, new.user_id, 'analytics_audit_sso_scim',
      '分析・監査・SSO・SCIM',
      'ワークスペース分析、監査ログ、SAML SSO、SCIM、管理者統制',
      array['/app-analytics-dashboard', '/access-control']
    ),
    (
      new.id, new.user_id, 'calendar_mail_connections',
      'カレンダー・メール連携',
      'Notion Calendar、メール・予定連携、受信箱、データベース同期',
      array['/google-calendar-sync', '/smart-inbox']
    )
  on conflict (batch_id, capability_key) do nothing;

  return new;
end;
$$;

create trigger notion_migration_batches_seed_capabilities
  after insert on public.notion_migration_batches
  for each row execute function public.notion_migration_seed_capabilities();

create or replace function public.notion_migration_guard_item_status()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  passed_checks integer;
begin
  if tg_op = 'UPDATE'
     and new.status is distinct from old.status
     and not (
       (old.status = 'inventoried' and new.status in (
         'queued', 'exporting', 'failed', 'skipped'
       ))
       or (old.status = 'queued' and new.status in (
         'exporting', 'failed', 'skipped'
       ))
       or (old.status = 'exporting' and new.status in ('imported', 'failed'))
       or (old.status = 'imported' and new.status in ('verifying', 'failed'))
       or (old.status = 'verifying' and new.status in ('verified', 'failed'))
       or (old.status = 'verified' and new.status in (
         'ready_for_source_deletion', 'failed'
       ))
       or (old.status = 'ready_for_source_deletion' and new.status in (
         'source_deleted', 'failed'
       ))
       or (old.status = 'failed' and new.status in (
         'queued', 'exporting', 'verifying'
       ))
       or (old.status = 'skipped' and new.status = 'queued')
     ) then
    raise exception 'notion_migration_invalid_item_transition'
      using errcode = '23514';
  end if;

  if new.status in (
    'imported',
    'verifying',
    'verified',
    'ready_for_source_deletion',
    'source_deleted'
  ) and (
    new.destination_kind is null
    or new.destination_id is null
    or new.imported_at is null
  ) then
    raise exception 'notion_migration_destination_evidence_required'
      using errcode = '23514';
  end if;

  if new.status in (
    'verified',
    'ready_for_source_deletion',
    'source_deleted'
  ) then
    select count(*)::integer
      into passed_checks
      from public.notion_migration_checks as migration_check
      where migration_check.item_id = new.id
        and migration_check.user_id = new.user_id
        and migration_check.status = 'passed';

    if passed_checks <> 7 then
      raise exception 'notion_migration_seven_checks_required'
        using errcode = '23514';
    end if;

    if new.verified_at is null then
      raise exception 'notion_migration_verification_timestamp_required'
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'ready_for_source_deletion'
     and new.deletion_authorized_at is null then
    raise exception 'notion_migration_deletion_authorization_required'
      using errcode = '23514';
  end if;

  if new.status = 'source_deleted' then
    if tg_op = 'INSERT'
       or old.status <> 'ready_for_source_deletion'
       or new.deletion_authorized_at is null
       or new.source_deleted_at is null then
      raise exception 'notion_migration_source_deletion_not_ready'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger notion_migration_items_guard_status
  before insert or update on public.notion_migration_items
  for each row execute function public.notion_migration_guard_item_status();

create or replace function public.notion_migration_guard_batch_completion()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status = 'completed' then
    if not exists (
      select 1
      from public.notion_migration_capabilities as capability
      where capability.batch_id = new.id
        and capability.user_id = new.user_id
        and capability.is_required
    ) or exists (
      select 1
      from public.notion_migration_capabilities as capability
      where capability.batch_id = new.id
        and capability.user_id = new.user_id
        and capability.is_required
        and capability.status <> 'verified'
    ) then
      raise exception 'notion_migration_capabilities_incomplete'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.notion_migration_items as item
      where item.batch_id = new.id and item.user_id = new.user_id
    ) or exists (
      select 1
      from public.notion_migration_items as item
      where item.batch_id = new.id
        and item.user_id = new.user_id
        and item.status <> 'source_deleted'
    ) then
      raise exception 'notion_migration_batch_items_incomplete'
        using errcode = '23514';
    end if;
    new.completed_at = coalesce(new.completed_at, now());
  end if;
  return new;
end;
$$;

create trigger notion_migration_batches_guard_completion
  before insert or update on public.notion_migration_batches
  for each row execute function public.notion_migration_guard_batch_completion();

create view public.notion_migration_batch_progress
with (security_invoker = true)
as
select
  batch.id as batch_id,
  batch.user_id,
  count(item.id)::bigint as total_items,
  count(item.id) filter (
    where item.status in (
      'imported',
      'verifying',
      'verified',
      'ready_for_source_deletion',
      'source_deleted'
    )
  )::bigint as imported_items,
  count(item.id) filter (
    where item.status in (
      'verified',
      'ready_for_source_deletion',
      'source_deleted'
    )
  )::bigint as verified_items,
  count(item.id) filter (
    where item.status = 'ready_for_source_deletion'
  )::bigint as deletion_ready_items,
  count(item.id) filter (
    where item.status = 'source_deleted'
  )::bigint as source_deleted_items,
  count(item.id) filter (where item.status = 'failed')::bigint
    as failed_items
from public.notion_migration_batches as batch
left join public.notion_migration_items as item
  on item.batch_id = batch.id and item.user_id = batch.user_id
group by batch.id, batch.user_id;

revoke all on table public.notion_migration_batch_progress
  from anon, authenticated;
grant select on table public.notion_migration_batch_progress to authenticated;
grant select on table public.notion_migration_batch_progress to service_role;

create view public.notion_migration_capability_progress
with (security_invoker = true)
as
select
  batch.id as batch_id,
  batch.user_id,
  count(capability.id) filter (
    where capability.is_required
  )::bigint as required_capabilities,
  count(capability.id) filter (
    where capability.is_required and capability.status = 'verified'
  )::bigint as verified_capabilities,
  count(capability.id) filter (
    where capability.is_required and capability.status = 'gap'
  )::bigint as gap_capabilities,
  count(capability.id) filter (
    where capability.is_required and capability.status = 'blocked'
  )::bigint as blocked_capabilities
from public.notion_migration_batches as batch
left join public.notion_migration_capabilities as capability
  on capability.batch_id = batch.id and capability.user_id = batch.user_id
group by batch.id, batch.user_id;

revoke all on table public.notion_migration_capability_progress
  from anon, authenticated;
grant select on table public.notion_migration_capability_progress
  to authenticated;
grant select on table public.notion_migration_capability_progress
  to service_role;

create view public.notion_migration_wbs_stage_progress
with (security_invoker = true)
as
select
  batch.id as batch_id,
  batch.user_id,
  count(staged.id) filter (
    where staged.is_current
  )::bigint as staged_rows,
  count(distinct staged.task_id) filter (
    where staged.is_current and staged.task_id <> ''
  )::bigint as distinct_task_ids,
  count(staged.id) filter (
    where staged.is_current and staged.duplicate_ordinal > 1
  )::bigint as duplicate_rows,
  count(staged.id) filter (
    where staged.is_current and staged.task_id = ''
  )::bigint as invalid_task_ids,
  max(staged.staged_at) filter (
    where staged.is_current
  ) as staged_at
from public.notion_migration_batches as batch
left join public.notion_migration_wbs_staging as staged
  on staged.batch_id = batch.id and staged.user_id = batch.user_id
group by batch.id, batch.user_id;

revoke all on table public.notion_migration_wbs_stage_progress
  from anon, authenticated;
grant select on table public.notion_migration_wbs_stage_progress
  to authenticated;
grant select on table public.notion_migration_wbs_stage_progress
  to service_role;

revoke execute on function public.notion_migration_touch_updated_at()
  from public, anon, authenticated;
revoke execute on function public.notion_migration_seed_capabilities()
  from public, anon, authenticated;
revoke execute on function public.notion_migration_guard_item_status()
  from public, anon, authenticated;
revoke execute on function public.notion_migration_guard_batch_completion()
  from public, anon, authenticated;
