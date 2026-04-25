-- PS#4 S52 fix: competitors スキーマ拡張を batch2 より前に実行
-- 20260426090000_competitors_schema_v2.sql と同内容だが timestamp を 005000 に前出し。
-- 理由: batch2-7 (010000-060000) が name/website_url 等の新カラムを使うため、
--       090000 では遅すぎて SQLSTATE 42703 で CI が落ちる。
-- 090000 はそのまま残す (ADD COLUMN IF NOT EXISTS で冪等)。

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

-- website → website_url
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

-- market_cap → funding_or_valuation
UPDATE public.competitors
SET funding_or_valuation = '$' || (market_cap / 1000000000)::text || 'B valuation'
WHERE funding_or_valuation IS NULL AND market_cap IS NOT NULL AND market_cap > 0;

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
