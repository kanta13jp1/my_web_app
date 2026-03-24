-- ============================================================
-- Migration: 2026-03-25
-- Growth tables: development_achievements, growth_plans
-- ============================================================

-- ---- development_achievements --------------------------------
-- 開発実績を記録するテーブル。DevelopmentAchievementsCard と
-- development-achievements Edge Function が参照する。

create table if not exists public.development_achievements (
  id            bigserial primary key,
  title         text        not null,
  completed_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

-- 全ユーザーが読み取り可能（開発実績は公開情報）
alter table public.development_achievements enable row level security;

create policy "Anyone can read development_achievements"
  on public.development_achievements
  for select
  using (true);

-- 認証ユーザーのみ追加可能
create policy "Authenticated users can insert development_achievements"
  on public.development_achievements
  for insert
  to authenticated
  with check (true);

-- ---- growth_plans -------------------------------------------
-- 競合対比ロードマップ計画データ。get-growth-roadmap-progress
-- Edge Function が参照・自動シードする。

create table if not exists public.growth_plans (
  id         bigserial primary key,
  label      text    not null,
  deadline   text    not null,  -- 'yyyy年MM月dd日' 形式
  target     integer not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.growth_plans enable row level security;

create policy "Anyone can read growth_plans"
  on public.growth_plans
  for select
  using (true);

-- Service role (Edge Function) のみ書き込み可
create policy "Service role can manage growth_plans"
  on public.growth_plans
  for all
  to service_role
  using (true)
  with check (true);

-- ---- home_daily_status --------------------------------------
-- ホーム画面の日次ステータス（モーニングブリーフィング・残高確認）。

create table if not exists public.home_daily_status (
  id                    bigserial primary key,
  user_id               uuid        not null references auth.users(id) on delete cascade,
  status_date           text        not null,  -- 'yyyy-MM-dd'
  morning_briefing_done boolean     not null default false,
  balance_check_done    boolean     not null default false,
  updated_at            timestamptz not null default now(),
  constraint home_daily_status_user_date_unique unique (user_id, status_date)
);

alter table public.home_daily_status enable row level security;

create policy "Users manage own home_daily_status"
  on public.home_daily_status
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---- インデックス --------------------------------------------
create index if not exists idx_development_achievements_completed_at
  on public.development_achievements (completed_at desc);

create index if not exists idx_growth_plans_sort_order
  on public.growth_plans (sort_order asc, target asc);

create index if not exists idx_home_daily_status_user_date
  on public.home_daily_status (user_id, status_date);
