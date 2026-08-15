-- 表示モード実験 (新規ユーザー=標準既定) のサーバ側集約 (Issue #3253)
-- クライアント (asset_management_page) が初期解決とモード切替を非同期送信する。
-- 送信失敗時はローカル (SharedPreferences) のみで継続する v1 設計。

create table if not exists public.display_mode_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  event_type text not null check (event_type in ('initial', 'switch')),
  mode text not null check (mode in ('minimum', 'standard', 'full')),
  has_data boolean,
  created_at timestamptz not null default now()
);

create index if not exists display_mode_events_user_created_idx
  on public.display_mode_events (user_id, created_at desc);

alter table public.display_mode_events enable row level security;

drop policy if exists "display_mode_events_insert_own"
  on public.display_mode_events;
create policy "display_mode_events_insert_own"
  on public.display_mode_events
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "display_mode_events_select_own"
  on public.display_mode_events;
create policy "display_mode_events_select_own"
  on public.display_mode_events
  for select to authenticated
  using (auth.uid() = user_id);

-- 集計クエリ例 (#3253 受入基準3 / service_role で実行する想定):
--
-- 1) 新規ユーザーの標準維持率 (初期=standard のうち、その後 switch していない割合)
--   select
--     count(*) filter (where not exists (
--       select 1 from display_mode_events s
--       where s.user_id = i.user_id and s.event_type = 'switch'
--         and s.created_at > i.created_at
--     ))::numeric / greatest(count(*), 1) as standard_retention_rate
--   from display_mode_events i
--   where i.event_type = 'initial' and i.mode = 'standard';
--
-- 2) 初期モード別の最終到達モード分布 (フル昇格率 / ミニマム降格率)
--   select i.mode as initial_mode, last.mode as final_mode, count(*)
--   from display_mode_events i
--   join lateral (
--     select mode from display_mode_events e
--     where e.user_id = i.user_id
--     order by e.created_at desc limit 1
--   ) last on true
--   where i.event_type = 'initial'
--   group by 1, 2 order by 1, 3 desc;
