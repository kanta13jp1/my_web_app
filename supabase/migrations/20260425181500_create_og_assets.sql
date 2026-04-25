-- Win版#132 part 14: OGP / 動画 / X 投稿の生成履歴テーブル
--
-- 契機: ユーザー要請「OGP 画像自動更新 + AI 動画 + X 投稿」
-- 設計: docs/OGP_VIDEO_AUTO_POST.md (3-Phase 計画)
--
-- 本 migration の目的:
--   1. og_assets テーブル新設
--   2. AI 生成 asset (画像 / 動画 / X 投稿) の履歴 / cost / X 投稿状態を一元管理

CREATE TABLE IF NOT EXISTS public.og_assets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_type      text NOT NULL CHECK (asset_type IN ('ogp_image','ad_video','x_post')),
  url             text NOT NULL,
  prompt          text,
  generated_by    text,                   -- 'fal-flux-schnell' / 'fal-ltx2' / 'hedra' / 'manual'
  cost_usd        numeric DEFAULT 0,
  posted_to_x     boolean DEFAULT false,
  x_post_id       text,                   -- X 投稿の tweet_id
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_og_assets_type_created
  ON public.og_assets (asset_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_og_assets_pending_x_post
  ON public.og_assets (posted_to_x)
  WHERE posted_to_x = false;

COMMENT ON TABLE public.og_assets IS
  'OGP 画像 / AI 動画 / X 投稿の生成履歴 + cost tracking + X 投稿状態 / Win#132 part 14';

COMMENT ON COLUMN public.og_assets.asset_type IS
  'ogp_image (週次 1200x630) / ad_video (月次 15-30秒) / x_post (tweet record)';

-- ============================================================
-- RLS (public read / service_role write)
-- ============================================================
ALTER TABLE public.og_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "og_assets public read" ON public.og_assets;
CREATE POLICY "og_assets public read" ON public.og_assets
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "og_assets service write" ON public.og_assets;
CREATE POLICY "og_assets service write" ON public.og_assets
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'OGP / 動画 / X 投稿 生成履歴テーブル',
  $md$Win版#132 part 14。ユーザー要請「OGP 画像自動更新 + AI 動画 X 投稿」を受けた 3-Phase 計画 (Phase 1: OGP / Phase 2: 動画 / Phase 3: X 投稿) の基盤テーブル。asset_type / url / prompt / generated_by / cost_usd / posted_to_x / x_post_id / metadata 8 カラム + 2 index (type+created / pending_x_post 部分 index) + RLS (public read / service_role write)。後続 GHA cron (ogp-image-refresh.yml 週次) が本テーブルに記録。docs/OGP_VIDEO_AUTO_POST.md。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
