-- Win版#132 part 27: competitors.threat_level CHECK 拡張 — 'critical' 値を許容
--
-- 契機: PS#4 S50 の Phase 3 batch 3 seed (20260426020000_seed_competitors_phase3_batch3.sql)
-- が threat_level='critical' を多数 (notion-ai/cloudsign 等) 投入しようとして
-- SQLSTATE 23514 で失敗。元の CHECK は 'high'/'medium'/'low' のみ許容。
--
-- 修正: 既存 inline CHECK 制約を drop して 4 値許容の named CHECK に置換 (idempotent)。
-- 既存データは 'high'/'medium'/'low' のみなので validation 影響なし。
--
-- batch 3 (020000) 実行前に必ず通る位置 (015000) に配置。

DO $$
DECLARE
  cons_name text;
BEGIN
  -- inline CHECK は anonymous なので pg_constraint から動的に拾って drop
  FOR cons_name IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.competitors'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%threat_level%'
  LOOP
    EXECUTE format('ALTER TABLE public.competitors DROP CONSTRAINT IF EXISTS %I', cons_name);
  END LOOP;
END $$;

-- 4 値許容の named CHECK を再付与
ALTER TABLE public.competitors
  ADD CONSTRAINT competitors_threat_level_check
  CHECK (threat_level IS NULL OR threat_level IN ('critical', 'high', 'medium', 'low'));

COMMENT ON CONSTRAINT competitors_threat_level_check ON public.competitors IS
  '脅威度。critical = 直接競合 (notion-ai/cloudsign 等) / high / medium / low の 4 段階。
   PS#4 S50 Phase 3 batch 3 で critical 値が必要となり 2026-04-25 part 27 で拡張。';
