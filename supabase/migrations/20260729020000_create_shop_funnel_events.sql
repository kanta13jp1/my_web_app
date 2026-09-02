-- 販売 funnel の計測 (2026-07-29)
--
-- 目的: HexCiv の買い切り販売で「どこで落ちているか」を測る。現状は購入完了しか
-- 記録がなく、閲覧も購入ボタン押下も残っていないため、施策の効果を判定できない。
--
-- 既存の first_user_acquisition_events は流用しない。あちらは
-- `utm_source = 'x'` / `utm_campaign = 'first_user_growth'` が CHECK 制約で固定された
-- **単一キャンペーン専用**のテーブルで、制約を緩めると2つの計測目的が混ざる。
--
-- 設計の要点:
--  * **source を必ず持たせる**。itch.io / X / 直接流入を区別できないと、
--    「どのチャネルが効いたか」が最後まで分からない。これが計測の主目的。
--  * 主キーを (visitor_id, product_id, source, stage) にして、
--    **同じ訪問者の同じ段は1回だけ**数える。イベント数でなく到達人数を見たいため。
--  * 個人を特定する値は持たない (IP・生 User-Agent は保存しない)。
--    visitor_id はブラウザ側で生成する乱数で、こちらから人物には結び付かない。
--  * 書き込みは service role のみ。既存の acquisition テーブルと同じ作法で、
--    利用者トークンからは書けない (Edge Function 経由にする)。

create table if not exists public.shop_funnel_events (
  -- ブラウザ側で生成して localStorage に保持する乱数。人物とは結び付かない。
  visitor_id uuid not null,
  product_id text not null references public.shop_products(id) on delete cascade,

  stage text not null
    check (
      stage in (
        'product_view',      -- 商品ページが開かれた
        'purchase_click',    -- 購入ボタンが押された
        'checkout_redirect', -- Stripe の Checkout URL が返った
        'purchase_complete'  -- webhook が入金を記録した (サーバ側の真実)
      )
    ),

  -- 流入元。utm_source が無い場合は 'direct'。ここが計測の肝。
  source text not null default 'direct'
    check (source ~ '^[a-z0-9_.-]{1,64}$'),
  -- 任意の補助軸 (キャンペーン名や投稿の識別子)。無ければ空文字。
  campaign text not null default ''
    check (campaign ~ '^[a-z0-9_.-]{0,64}$'),

  -- ログイン済みなら紐付ける。未ログインの閲覧も数えたいので null 可。
  auth_user_id uuid references auth.users(id) on delete set null,

  first_occurred_at timestamptz not null default now(),

  primary key (visitor_id, product_id, source, stage)
);

comment on table public.shop_funnel_events is
  '買い切り販売の到達人数 funnel。同じ訪問者の同じ段は1回だけ数える。個人特定情報は持たない。';
comment on column public.shop_funnel_events.source is
  '流入元 (itch_io / x / direct 等)。これが無いとチャネル別の効果を判定できない。';
comment on column public.shop_funnel_events.visitor_id is
  'ブラウザ側で生成する乱数。IP や User-Agent は保存しない。';

-- 集計の主経路: 商品×流入元×段 で人数を数える
create index if not exists shop_funnel_events_report_idx
  on public.shop_funnel_events (product_id, source, stage, first_occurred_at desc);

-- ============================================================
-- RLS
-- ============================================================
-- 既存の first_user_acquisition_events と同じ方針。
-- 利用者トークンから書けると、閲覧数をいくらでも捏造できてしまう。
-- 読みも塞ぐ (集計はダッシュボード側が service role で行う)。

alter table public.shop_funnel_events enable row level security;

revoke all on public.shop_funnel_events from public, anon, authenticated;

-- ポリシーは意図的に1つも作らない。
-- RLS 有効 + ポリシー不在 = service role 以外は読み書きできない、が既定の姿。
