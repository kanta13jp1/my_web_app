-- Win版#132 part 10: 競合 21→190 社化 Phase 1 — schema + 21 seed
--
-- 契機: ユーザー要請「AI大学のコンテンツ数と同数程度には増やしたい」
-- 設計: docs/COMPETITOR_EXPANSION_PLAN.md (3-Phase 計画)
--
-- 本 migration の目的:
--   1. competitors テーブル新設 (拡張可能基盤)
--   2. competitor_features テーブル新設 (機能パリティ管理)
--   3. 既存 21 社を seed (lib/pages/comparison_page.dart の _CompetitorInfo から抽出)
--
-- 後続:
--   - Phase 1-4: Flutter UI を const map → Supabase fetch にリファクタ (VSCode 担当)
--   - Phase 2: PS#4 が月次で 21→50→100 社に拡張
--   - Phase 3: competitor-discovery.yml で trending 自動 staging

-- ============================================================
-- 1. competitors テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS public.competitors (
  id            text PRIMARY KEY,
  display_name  text NOT NULL,
  category      text NOT NULL,
  website       text,
  description   text,
  logo_url      text,
  market_cap    bigint,
  user_count    bigint,
  founded_year  int,
  hq_location   text,
  features      jsonb DEFAULT '{}'::jsonb,
  jp_strength   text,
  jp_weakness   text,
  is_active     boolean DEFAULT true,
  sort_order    int DEFAULT 100,
  added_at      timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competitors_category ON public.competitors (category);
CREATE INDEX IF NOT EXISTS idx_competitors_active_sort ON public.competitors (is_active, sort_order);

COMMENT ON TABLE public.competitors IS
  '競合企業マスタ (AI大学の ai_university_content と並ぶ拡張可能テーブル) / Phase 1 = 21 / 目標 = 190 / docs/COMPETITOR_EXPANSION_PLAN.md';
COMMENT ON COLUMN public.competitors.category IS
  'productivity / fintech / chat / ai-coding / cloud-office / hr-attendance / specialty';

-- ============================================================
-- 2. competitor_features テーブル (機能パリティ)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.competitor_features (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id   text REFERENCES public.competitors(id) ON DELETE CASCADE,
  feature_key     text NOT NULL,
  feature_name_ja text NOT NULL,
  has_feature     boolean DEFAULT false,
  jibun_status    text DEFAULT 'notYet',
  notes           text,
  updated_at      timestamptz DEFAULT now(),
  UNIQUE (competitor_id, feature_key)
);

CREATE INDEX IF NOT EXISTS idx_competitor_features_competitor
  ON public.competitor_features (competitor_id);

COMMENT ON TABLE public.competitor_features IS
  '競合の機能リスト + 自分株式会社の対応状況 / 既存 competitor_feature_status (= 自分側 status のみ) と独立';

-- ============================================================
-- 3. RLS (public read / service_role write)
-- ============================================================
ALTER TABLE public.competitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitor_features ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "competitors public read" ON public.competitors;
CREATE POLICY "competitors public read" ON public.competitors
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "competitors service write" ON public.competitors;
CREATE POLICY "competitors service write" ON public.competitors
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "competitor_features public read" ON public.competitor_features;
CREATE POLICY "competitor_features public read" ON public.competitor_features
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "competitor_features service write" ON public.competitor_features;
CREATE POLICY "competitor_features service write" ON public.competitor_features
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 4. 既存 21 社 seed
-- ============================================================
INSERT INTO public.competitors (id, display_name, category, website, description, sort_order)
VALUES
  -- Productivity (note / second-brain)
  ('notion',       'Notion',       'productivity', 'https://www.notion.so/',       'オールインワン workspace (Notes/Wiki/DB/AI)', 10),
  ('evernote',     'Evernote',     'productivity', 'https://evernote.com/',        '老舗 note app / 検索強い (Bending Spoons 買収)', 20),

  -- Fintech / Money
  ('moneyforward', 'MoneyForward', 'fintech',      'https://moneyforward.com/',    '日本 No.1 家計簿 + 法人会計 (FY2030 ¥150B ARR 目標)', 30),

  -- Chat / Communication
  ('slack',        'Slack',        'chat',         'https://slack.com/',           '法人 chat 標準 (Salesforce 傘下 / Agentforce 統合)', 40),
  ('chatwork',     'Chatwork',     'chat',         'https://www.chatwork.com/',    '日本中小企業向け chat / KDDI 完全子会社化', 50),
  ('discord',      'Discord',      'chat',         'https://discord.com/',         'ゲーマー → コミュニティ chat (200M+ MAU)', 60),
  ('line',         'LINE',         'chat',         'https://line.me/',             '日本 No.1 messenger (196M MAU / 経済圏)', 70),
  ('x',            'X (旧 Twitter)','sns',         'https://x.com/',               'Musk 買収後の SNS / Grok 統合', 80),
  ('facebook',     'Facebook (Meta)','sns',        'https://facebook.com/',        '世界最大 SNS (3B+ MAU / Meta AI 統合)', 90),

  -- AI Coding
  ('claude-code',  'Claude Code',  'ai-coding',    'https://claude.com/claude-code','Anthropic 公式 CLI agent (本プロジェクトでも使用)', 100),
  ('codex',        'OpenAI Codex', 'ai-coding',    'https://openai.com/codex',     'OpenAI コード補完 / Cursor / Aider のベース', 110),
  ('claude-cowork','Claude for Work','ai-coding',  'https://claude.com/work',      'Anthropic Enterprise (Slack/Notion 統合 chat)', 120),
  ('openclaw',     'OpenClaw',     'ai-coding',    NULL,                           'OSS Claude 互換 CLI (代替実装)', 130),

  -- Cloud Office / Big Tech
  ('amazon',       'Amazon',       'cloud-office', 'https://amazon.com/',          'EC + AWS + Alexa AI (310M Prime user)', 140),
  ('google',       'Google',       'cloud-office', 'https://google.com/',          'Workspace + Gemini + Cloud (4.3B user)', 150),
  ('microsoft',    'Microsoft',    'cloud-office', 'https://microsoft.com/',       'Office 365 + Copilot + Azure (1.5B user)', 160),
  ('github',       'GitHub',       'cloud-office', 'https://github.com/',          'コード ホスト + Copilot (100M+ developer)', 170),

  -- HR / Attendance
  ('jobcan',       'ジョブカン',    'hr-attendance','https://jobcan.ne.jp/',        '日本中小企業向け勤怠/HR (5M user)', 180),

  -- Specialty
  ('netkeiba',     'netkeiba',     'specialty',    'https://www.netkeiba.com/',    '日本 No.1 競馬データ (17M user / horse_racing 機能対象)', 190),
  ('animaworks',   'Animaworks',   'specialty',    NULL,                           '動画制作系 SaaS (500K user)', 200),
  ('liven',        'Liven',        'specialty',    NULL,                           'ライフログ系 (1M user)', 210)
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  category     = EXCLUDED.category,
  website      = EXCLUDED.website,
  description  = EXCLUDED.description,
  sort_order   = EXCLUDED.sort_order,
  updated_at   = now();

-- ============================================================
-- 5. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競合 DB 化 Phase 1: competitors テーブル + 21 社 seed',
  $md$Win版#132 part 10。ユーザー要請「AI大学並み 190 社化」を受けた 3-Phase 計画の Phase 1 実装。competitors テーブル + competitor_features テーブル (機能パリティ) + RLS (public read / service_role write) + 既存 21 社 seed (productivity / fintech / chat / sns / ai-coding / cloud-office / hr-attendance / specialty 8 カテゴリに分類)。後続: Phase 1-4 で Flutter UI を Supabase fetch にリファクタ (VSCode handoff) / Phase 2 で PS#4 月次拡張 21→50→100 社 / Phase 3 で competitor-discovery.yml 自動 staging。docs/COMPETITOR_EXPANSION_PLAN.md。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
