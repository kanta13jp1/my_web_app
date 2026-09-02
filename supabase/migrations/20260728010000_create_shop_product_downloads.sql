-- 有料ダウンロード販売の基盤 (2026-07-28)
--
-- 目的: HexCiv (Unity 製 Windows ゲーム) を自分株式会社のサイトから有料配布する。
-- 既存の billing_subscriptions は「サブスクの階層 (free/pro/team)」用で、
-- 単品買い切りの商品と、その購入者だけが取得できるファイルの概念は無かった。
--
-- 設計の要点:
--  * 商品ファイルは **非公開バケット** に置き、購入者にだけ有効期限付きの
--    署名付きURLを Edge Function が発行する。バケットを公開にすると URL さえ
--    知られたら誰でも落とせるため、有料化が成立しない。
--  * 購入行は Stripe の checkout session id を **unique** にする。Stripe は
--    webhook を再送するので、これが無いと同じ支払いで購入が重複して入る。
--  * 商品は既定で **is_active = false**。ファイルの実体を置いて Stripe の Price を
--    紐づけ終わるまで売れないようにし、「買えたのに落とせない」事故を防ぐ。
--  * 支払金額は購入行に控える。後から値段を変えても、過去の購入額は変わらない。
--  * 書き込みは service role (webhook / EF) だけ。利用者側からは購入行を作れない。

-- ============================================================
-- 商品
-- ============================================================

create table if not exists public.shop_products (
  -- 人が読める安定 ID。Stripe の metadata に載せて webhook 側で引き当てる。
  id text primary key,
  name_ja text not null,
  summary_ja text,
  price_jpy integer not null check (price_jpy > 0),
  -- Stripe ダッシュボードで作る Price の ID。未設定のうちは購入導線を出さない。
  stripe_price_id text,
  -- 配信ファイルの所在 (非公開バケット内のパス)
  storage_bucket text not null default 'product-downloads',
  storage_path text not null,
  version text not null,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes > 0),
  -- 配信中のファイルが意図した版かを後から突き合わせるための実測値
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  -- 実体と価格が揃うまで false のまま。UI と EF の両方でこれを見る。
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.shop_products is
  '買い切り商品のカタログ。is_active が true のものだけ販売・配信の対象。';
comment on column public.shop_products.stripe_price_id is
  'Stripe の Price ID。未設定なら購入導線を出さない (金額の二重管理を避けるため決済側が正)。';
comment on column public.shop_products.sha256 is
  '配信ファイルの SHA256。差し替え事故を後から検出するための控え。';

-- ============================================================
-- 購入 (= ダウンロード権利)
-- ============================================================

create table if not exists public.shop_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null references public.shop_products(id) on delete restrict,
  -- Stripe の再送に対する冪等性の要。同じ session で二重に購入行を作らない。
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text,
  -- 購入時点の金額を控える (商品側の価格変更に影響されない)
  amount_jpy integer not null check (amount_jpy >= 0),
  currency text not null default 'jpy',
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'refunded', 'canceled')),
  purchased_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.shop_purchases is
  '買い切り購入の記録。status = paid の行がダウンロード権利そのもの。';
comment on column public.shop_purchases.stripe_checkout_session_id is
  'Stripe webhook は再送されるため、ここを unique にして購入の重複計上を防ぐ。';

create index if not exists shop_purchases_user_product_idx
  on public.shop_purchases (user_id, product_id);

-- 権利判定 (「この人はこの商品を買ったか」) の主経路。paid だけを対象にする。
create index if not exists shop_purchases_paid_idx
  on public.shop_purchases (user_id, product_id)
  where status = 'paid';

-- ============================================================
-- ダウンロード発行の記録
-- ============================================================
-- 署名付きURLを何回・いつ出したかを残す。異常な回数の発行に後から気づくため。
-- 生 IP は保存しない (必要なのは「同一かどうか」であって住所ではない)。

create table if not exists public.shop_download_events (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.shop_purchases(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null references public.shop_products(id) on delete restrict,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  user_agent text
);

comment on table public.shop_download_events is
  '署名付きURLの発行記録。発行回数の異常を後から検出するための監査用。';

create index if not exists shop_download_events_user_idx
  on public.shop_download_events (user_id, issued_at desc);

-- ============================================================
-- updated_at の自動更新
-- ============================================================

create or replace function public.shop_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists shop_products_touch on public.shop_products;
create trigger shop_products_touch
  before update on public.shop_products
  for each row execute function public.shop_touch_updated_at();

drop trigger if exists shop_purchases_touch on public.shop_purchases;
create trigger shop_purchases_touch
  before update on public.shop_purchases
  for each row execute function public.shop_touch_updated_at();

-- ============================================================
-- RLS
-- ============================================================
-- 方針: 読みは本人分だけ。書きは service role (webhook / EF) だけ。
-- 利用者のトークンで購入行を作れてしまうと、支払わずに権利を得られてしまう。

alter table public.shop_products enable row level security;
alter table public.shop_purchases enable row level security;
alter table public.shop_download_events enable row level security;

-- 商品: 販売中のものは誰でも読める (商品ページを未ログインでも見せるため)
drop policy if exists shop_products_public_read on public.shop_products;
create policy shop_products_public_read on public.shop_products
  for select
  to anon, authenticated
  using (is_active = true);

-- 購入: 本人の行だけ読める
drop policy if exists shop_purchases_self_read on public.shop_purchases;
create policy shop_purchases_self_read on public.shop_purchases
  for select
  to authenticated
  using (auth.uid() = user_id);

-- ダウンロード記録: 本人の行だけ読める
drop policy if exists shop_download_events_self_read on public.shop_download_events;
create policy shop_download_events_self_read on public.shop_download_events
  for select
  to authenticated
  using (auth.uid() = user_id);

-- insert / update / delete のポリシーは意図的に作らない。
-- RLS 有効かつポリシー不在 = service role 以外は書けない、が既定の姿。

-- ============================================================
-- 配信用の非公開バケット
-- ============================================================
-- public = false が肝。ここを true にすると URL を知る全員が落とせてしまう。
-- 上限は 500MB (現行の HexCiv zip は約 36MB。将来の同梱物増加に余裕を持たせる)。

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-downloads',
  'product-downloads',
  false,
  524288000,
  array['application/zip', 'application/octet-stream']
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- バケットに対する storage.objects のポリシーは作らない。
-- 取得は Edge Function が service role で発行する署名付きURL経由に限定する
-- (利用者のトークンで直接 storage を叩けないようにするため)。

-- ============================================================
-- 商品の初期登録
-- ============================================================
-- is_active = false のまま入れる。次の3つが揃った時点で手動で true にする:
--   1. product-downloads バケットへ zip を配置
--   2. Stripe で ¥500 の Price を作成し stripe_price_id を設定
--   3. 特定商取引法に基づく表記の公開

insert into public.shop_products (
  id, name_ja, summary_ja, price_jpy, storage_path, version,
  file_size_bytes, sha256, is_active
)
values (
  'hexciv-win64',
  'HexCiv (Windows 版)',
  '92文明・世界史図鑑・ウルク史実キャンペーンを収録した 4X ストラテジー。Claude Code と Codex の共同開発。',
  500,
  'hexciv/HexCiv-v1.0-win64.zip',
  '1.0',
  37572177,
  'cc0e5caae732fa123d26ed62c1827a923c4ccd777823190ed714ba178e97ed93',
  false
)
on conflict (id) do update
set
  name_ja = excluded.name_ja,
  summary_ja = excluded.summary_ja,
  price_jpy = excluded.price_jpy,
  storage_path = excluded.storage_path,
  version = excluded.version,
  file_size_bytes = excluded.file_size_bytes,
  sha256 = excluded.sha256;
