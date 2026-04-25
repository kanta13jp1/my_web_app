-- Win版#132 part 15: 全ページ X シェア機能 + AI 自動生成 Phase 1
--
-- 契機: ユーザー要請「全ページに X シェア機能 + ページごとに AI 文言・画像・動画 自動生成」
-- 設計: docs/PAGE_LEVEL_SHARE.md (4-Phase 計画)
--
-- 本 migration の目的:
--   1. page_shares テーブル新設 (per-page share asset cache / 7 日 TTL)
--   2. share_count で KPI 追跡

CREATE TABLE IF NOT EXISTS public.page_shares (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_path       text NOT NULL UNIQUE,         -- '/' / '/ai-university' / '/comparison/notion' etc
  page_title      text,                          -- "AI大学 — 200社のAI最新動向"
  page_description text,                         -- meta description / hint for AI
  tweet_text      text,                          -- AI 生成済 tweet (140字以内 / 280 byte safe)
  image_url       text,                          -- AI 生成画像 URL (FAL flux output / fallback ogp.png)
  video_url       text,                          -- (Phase 3) 動画 URL
  video_enabled   boolean DEFAULT false,         -- 動画生成対象 flag (high-traffic page のみ true)
  generated_by    text,                          -- 'gemini-flash+fal-flux-schnell' / 'fallback'
  cost_usd        numeric DEFAULT 0,
  share_count     int DEFAULT 0,                 -- KPI: 何回シェアされたか
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_page_shares_path ON public.page_shares (page_path);
CREATE INDEX IF NOT EXISTS idx_page_shares_freshness ON public.page_shares (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_page_shares_video_enabled
  ON public.page_shares (video_enabled)
  WHERE video_enabled = true;

COMMENT ON TABLE public.page_shares IS
  'per-page X シェア asset cache (tweet 文 / 画像 / 動画) / 7 日 TTL / Win#132 part 15';
COMMENT ON COLUMN public.page_shares.page_path IS
  'ページ path (例: /ai-university). UNIQUE で 1 page 1 row';
COMMENT ON COLUMN public.page_shares.share_count IS
  'KPI: シェアボタンが押された累計回数 (cache hit 含む)';
COMMENT ON COLUMN public.page_shares.video_enabled IS
  'Phase 3 動画生成対象 flag. LP / AI大学 / comparison など high-traffic page のみ true';

-- ============================================================
-- RLS (public read / service_role write — anon でも生成 trigger 可能だが書き込みは service_role)
-- ============================================================
ALTER TABLE public.page_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "page_shares public read" ON public.page_shares;
CREATE POLICY "page_shares public read" ON public.page_shares
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "page_shares service write" ON public.page_shares;
CREATE POLICY "page_shares service write" ON public.page_shares
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 初期 seed: 主要ページに video_enabled=true を予約
-- ============================================================
INSERT INTO public.page_shares (page_path, page_title, video_enabled)
VALUES
  ('/',                'TOP — 自分株式会社',                  true),
  ('/ai-university',   'AI大学 — 200+社のAI最新動向',         true),
  ('/comparison',      '競合比較 — 21+社の機能比較',          true),
  ('/landing',         'LP — Notion・Slack・MoneyForward を1つに', true),
  ('/project-gantt',   'Open Roadmap — 開発進捗ガントチャート', false),
  ('/feature-requests','機能リクエスト',                       false)
ON CONFLICT (page_path) DO NOTHING;

-- ============================================================
-- development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全ページ X シェア + AI 自動生成 Phase 1',
  $md$Win版#132 part 15。ユーザー要請「全ページに X シェア機能 + ページごとに AI が文言・画像・動画 自動生成」を受けた 4-Phase 計画 (Phase 1: page_shares テーブル + core-hub:page.share_generate / Phase 2: Flutter ShareToXButton widget VSCode / Phase 3: 動画 high-traffic 限定 / Phase 4: KPI ダッシュボード) の Phase 1 基盤テーブル。page_path UNIQUE / 7 日 TTL cache / share_count KPI / video_enabled flag / fallback 戦略 (Gemini fail → template / FAL fail → ogp.png) / Cost $2-3/月 (cache hit 効果込み)。docs/PAGE_LEVEL_SHARE.md。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
