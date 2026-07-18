-- 構造化タスク管理 (GitHub Issue Fields 相当) — 2026-07-12 WEB版
-- feature_requests / growth_plans に Priority / Effort / 期日フィールドを追加し、
-- 要望・ロードマップ計画を型付きメタデータで並べ替え・優先順位付けできるようにする。

-- ── feature_requests: priority / effort / target_date ───────────────────────
ALTER TABLE public.feature_requests
  ADD COLUMN IF NOT EXISTS priority text,
  ADD COLUMN IF NOT EXISTS effort text,
  ADD COLUMN IF NOT EXISTS target_date date;

-- 既存行や不正値を壊さないよう NULL 許容 + 値ドメインを CHECK で限定。
-- priority: p0(最優先) 〜 p3(低) / effort: xs〜xl (T シャツサイズ見積もり)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'feature_requests_priority_check'
  ) THEN
    ALTER TABLE public.feature_requests
      ADD CONSTRAINT feature_requests_priority_check
      CHECK (priority IS NULL OR priority IN ('p0', 'p1', 'p2', 'p3'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'feature_requests_effort_check'
  ) THEN
    ALTER TABLE public.feature_requests
      ADD CONSTRAINT feature_requests_effort_check
      CHECK (effort IS NULL OR effort IN ('xs', 's', 'm', 'l', 'xl'));
  END IF;
END $$;

COMMENT ON COLUMN public.feature_requests.priority IS
  '優先度 p0(最優先)〜p3(低)。管理者が設定。GitHub Issue Fields の Priority 相当。';
COMMENT ON COLUMN public.feature_requests.effort IS
  '工数見積もり xs/s/m/l/xl (T シャツサイズ)。GitHub Issue Fields の Effort 相当。';
COMMENT ON COLUMN public.feature_requests.target_date IS '対応目標日 (任意)。';

CREATE INDEX IF NOT EXISTS feature_requests_priority_idx
  ON public.feature_requests (priority)
  WHERE priority IS NOT NULL;

-- ── growth_plans: priority / effort ─────────────────────────────────────────
ALTER TABLE public.growth_plans
  ADD COLUMN IF NOT EXISTS priority text,
  ADD COLUMN IF NOT EXISTS effort text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'growth_plans_priority_check'
  ) THEN
    ALTER TABLE public.growth_plans
      ADD CONSTRAINT growth_plans_priority_check
      CHECK (priority IS NULL OR priority IN ('p0', 'p1', 'p2', 'p3'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'growth_plans_effort_check'
  ) THEN
    ALTER TABLE public.growth_plans
      ADD CONSTRAINT growth_plans_effort_check
      CHECK (effort IS NULL OR effort IN ('xs', 's', 'm', 'l', 'xl'));
  END IF;
END $$;

COMMENT ON COLUMN public.growth_plans.priority IS
  'ロードマップ計画の優先度 p0〜p3 (任意)。';
COMMENT ON COLUMN public.growth_plans.effort IS
  'ロードマップ計画の工数見積もり xs〜xl (任意)。';
