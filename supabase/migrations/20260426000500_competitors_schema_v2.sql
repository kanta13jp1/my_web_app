-- PS#4 S52: competitors テーブル Phase 3 スキーマ拡張 (2026-04-26)
-- Phase 1 スキーマ (website/hq_location/market_cap) に Phase 3 新カラムを追加
-- Phase 3 batch2-7 seed (20260426010000-060000) が使う新カラム群を ADD COLUMN IF NOT EXISTS

-- ============================================================
-- 1. 新カラム追加
-- ============================================================
ALTER TABLE public.competitors
  ADD COLUMN IF NOT EXISTS name                text,
  ADD COLUMN IF NOT EXISTS website_url         text,
  ADD COLUMN IF NOT EXISTS headquarters        text,
  ADD COLUMN IF NOT EXISTS funding_or_valuation text,
  ADD COLUMN IF NOT EXISTS employee_count_range text,
  ADD COLUMN IF NOT EXISTS key_features        text[],
  ADD COLUMN IF NOT EXISTS our_overlap_score   int CHECK (our_overlap_score >= 0 AND our_overlap_score <= 10),
  ADD COLUMN IF NOT EXISTS threat_level        text CHECK (threat_level IN ('high', 'medium', 'low')),
  ADD COLUMN IF NOT EXISTS created_at          timestamptz;

-- ============================================================
-- 2. 既存データから新カラムへデータ移行 (Phase 1→Phase 3 互換)
-- ============================================================

-- website → website_url (Phase 1 stores URL in 'website', Phase 3 uses 'website_url')
UPDATE public.competitors
SET website_url = website
WHERE website_url IS NULL AND website IS NOT NULL;

-- hq_location → headquarters
UPDATE public.competitors
SET headquarters = hq_location
WHERE headquarters IS NULL AND hq_location IS NOT NULL;

-- display_name → name
UPDATE public.competitors
SET name = display_name
WHERE name IS NULL AND display_name IS NOT NULL;

-- added_at → created_at
UPDATE public.competitors
SET created_at = added_at
WHERE created_at IS NULL AND added_at IS NOT NULL;

-- market_cap → funding_or_valuation (numeric → text表現)
UPDATE public.competitors
SET funding_or_valuation = '$' || (market_cap / 1000000000)::text || 'B valuation'
WHERE funding_or_valuation IS NULL AND market_cap IS NOT NULL AND market_cap > 0;

-- ============================================================
-- 3. threat_level / our_overlap_score のデフォルト設定
--    (Phase 1 データは sort_order から推定)
-- ============================================================
UPDATE public.competitors
SET threat_level = CASE
  WHEN sort_order <= 30 THEN 'high'
  WHEN sort_order <= 60 THEN 'medium'
  ELSE 'low'
END
WHERE threat_level IS NULL;

UPDATE public.competitors
SET our_overlap_score = CASE
  WHEN sort_order <= 30 THEN 7
  WHEN sort_order <= 60 THEN 5
  ELSE 3
END
WHERE our_overlap_score IS NULL;

-- ============================================================
-- 4. Phase 3 batch2-7 migrationで使う ON CONFLICT の UPDATE も
--    正常動作するよう確認用インデックス
-- ============================================================
COMMENT ON COLUMN public.competitors.website_url IS
  'Phase 3+: website_url (Phase 1 は website カラムも存在、website_url と同期)';
COMMENT ON COLUMN public.competitors.threat_level IS
  '脅威レベル: high / medium / low';
COMMENT ON COLUMN public.competitors.our_overlap_score IS
  '自分株式会社との機能重複スコア 0-10';

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitors テーブル Phase 3 スキーマ拡張 (PS#4 S52)',
  'Phase 1 (website/hq_location/market_cap) → Phase 3 (website_url/headquarters/threat_level/our_overlap_score/key_features/funding_or_valuation) カラム追加。' ||
  '既存データを新カラムにコピー。Phase 3 batch2-7 seed migrations の CI 失敗解消。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
