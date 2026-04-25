-- PS#4 S51: Phase 3 自動 discovery — competitor_candidates テーブル (2026-04-26)
-- 週次 GHA が発掘した候補を staging → PS#4 review → competitors に promote

CREATE TABLE IF NOT EXISTS public.competitor_candidates (
  id                text PRIMARY KEY,
  display_name      text NOT NULL,
  category          text,
  website           text,
  description       text,
  source            text DEFAULT 'gemini-discovery',  -- 'gemini-discovery' / 'manual-add' / etc
  ai_score          numeric CHECK (ai_score >= 0 AND ai_score <= 1),
  threat_level      text CHECK (threat_level IN ('high', 'medium', 'low')),
  founded_year      int,
  headquarters      text,
  funding           text,
  key_features      text[],
  our_overlap_score int CHECK (our_overlap_score >= 0 AND our_overlap_score <= 10),
  reviewed          boolean DEFAULT false,
  promoted          boolean DEFAULT false,
  rejected_reason   text,
  staged_at         timestamptz DEFAULT now(),
  reviewed_at       timestamptz,
  promoted_at       timestamptz,
  discovery_week    text,  -- 'YYYY-WW' 形式で検索用
  raw_gemini_output text   -- Gemini の生出力 (デバッグ用)
);

ALTER TABLE public.competitor_candidates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read competitor_candidates"
  ON public.competitor_candidates FOR SELECT
  TO public USING (true);

CREATE POLICY "Service role write competitor_candidates"
  ON public.competitor_candidates FOR ALL
  TO service_role USING (true);

CREATE INDEX IF NOT EXISTS idx_competitor_candidates_reviewed
  ON public.competitor_candidates (reviewed, promoted, staged_at DESC);

CREATE INDEX IF NOT EXISTS idx_competitor_candidates_week
  ON public.competitor_candidates (discovery_week);

COMMENT ON TABLE public.competitor_candidates IS
  'Phase 3 自動 discovery の staging テーブル。週次 GHA が Gemini で発掘 → PS#4 review → competitors に promote。';

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Phase 3 competitor_candidates テーブル作成 (PS#4 S51)',
  'competitor-discovery.yml 週次自動発掘の staging テーブル。' ||
  'ai_score + threat_level + reviewed/promoted フラグ + discovery_week で管理。' ||
  'RLS: public read / service_role write。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
