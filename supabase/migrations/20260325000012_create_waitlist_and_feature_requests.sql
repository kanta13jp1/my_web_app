-- ============================================================
-- ウェイトリスト登録テーブル (newsletter_waitlist)
-- 登録前のメールアドレス収集・関心度計測用
-- ============================================================

create table if not exists public.newsletter_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text not null default 'landing',   -- landing / import_cta / referral 等
  note text,
  created_at timestamptz not null default now()
);

-- 公開なし: サービスロールのみアクセス可
alter table public.newsletter_waitlist enable row level security;

-- 登録は誰でも可（anon 含む）
create policy "anyone can insert waitlist"
  on public.newsletter_waitlist
  for insert
  to anon, authenticated
  with check (true);

-- 参照はサービスロールのみ（管理者が確認）
create policy "service role can select waitlist"
  on public.newsletter_waitlist
  for select
  to service_role
  using (true);

-- ============================================================
-- 機能リクエストテーブル (feature_requests)
-- ユーザー・未登録者からの機能提案を収集
-- ============================================================

create table if not exists public.feature_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(user_id) on delete set null,
  email text,
  title text not null,
  description text,
  votes integer not null default 1,
  status text not null default 'open',  -- open / in_progress / done / rejected
  created_at timestamptz not null default now()
);

alter table public.feature_requests enable row level security;

-- 誰でも投稿可
create policy "anyone can insert feature_requests"
  on public.feature_requests
  for insert
  to anon, authenticated
  with check (true);

-- 認証済みユーザーは自分の投稿を参照可
create policy "authenticated can select feature_requests"
  on public.feature_requests
  for select
  to authenticated
  using (true);

-- anon も参照可（公開投票）
create policy "anon can select feature_requests"
  on public.feature_requests
  for select
  to anon
  using (status = 'open');

create index if not exists feature_requests_status_idx
  on public.feature_requests(status);
create index if not exists feature_requests_votes_idx
  on public.feature_requests(votes desc);
