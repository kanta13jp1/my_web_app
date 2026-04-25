-- Win版#132 part 17: WBS タスク動的再分担 (Rebalance) Phase 1
--
-- 契機: ユーザー要請「instance 毎にタスク量に偏り / 担当作業ない instance / 各セッションで
-- 役割見直し / 滞留タスクを自担当に変更する臨機応変」
-- 設計: docs/WBS_REBALANCE.md (3-Phase 計画)
--
-- 本 migration の目的:
--   1. wbs_rebalance_log テーブル新設 (audit log / 戻し可能性)
--   2. wbs_tasks 拡張 2 カラム (last_rebalanced_at / rebalance_count)
--
-- 後続 (新 session):
--   - Phase 1-EF: tools-hub に wbs.rebalance_suggest + wbs.claim_task action 追加 (本 commit 同時)
--   - Phase 2: session-start hook 改善 ([WBS-SYNC] rule で auto-suggest)
--   - Phase 3: instance load KPI dashboard

-- ============================================================
-- 1. wbs_rebalance_log テーブル新設
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wbs_rebalance_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         uuid REFERENCES public.wbs_tasks(id) ON DELETE CASCADE,
  from_instance   text NOT NULL,
  to_instance     text NOT NULL,
  from_owner      text,
  to_owner        text,
  reason          text,
  stale_score     int,
  triggered_by    text,
  metadata        jsonb DEFAULT '{}'::jsonb,
  rebalanced_at   timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wbs_rebalance_log_task
  ON public.wbs_rebalance_log (task_id, rebalanced_at DESC);

CREATE INDEX IF NOT EXISTS idx_wbs_rebalance_log_to_instance
  ON public.wbs_rebalance_log (to_instance, rebalanced_at DESC);

COMMENT ON TABLE public.wbs_rebalance_log IS
  'WBS タスク動的再分担の監査 log / Win#132 part 17 / docs/WBS_REBALANCE.md';
COMMENT ON COLUMN public.wbs_rebalance_log.reason IS
  'auto_idle_session / manual_review / ai_load_balance / urgent_takeover';
COMMENT ON COLUMN public.wbs_rebalance_log.triggered_by IS
  'session-start / user / cron / wbs-stale-subdivide';

-- ============================================================
-- 2. wbs_tasks 拡張 2 カラム
-- ============================================================
ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS last_rebalanced_at timestamptz,
  ADD COLUMN IF NOT EXISTS rebalance_count int DEFAULT 0;

COMMENT ON COLUMN public.wbs_tasks.last_rebalanced_at IS
  '直近 rebalance 時刻 (loop 防止 / 7 日以内は再 rebalance 不可)';
COMMENT ON COLUMN public.wbs_tasks.rebalance_count IS
  '累計 rebalance 回数 (KPI / 高い = orphan task の指標)';

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_last_rebalanced
  ON public.wbs_tasks (last_rebalanced_at DESC)
  WHERE last_rebalanced_at IS NOT NULL;

-- ============================================================
-- 3. RLS (public read / service_role write)
-- ============================================================
ALTER TABLE public.wbs_rebalance_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wbs_rebalance_log public read" ON public.wbs_rebalance_log;
CREATE POLICY "wbs_rebalance_log public read" ON public.wbs_rebalance_log
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "wbs_rebalance_log service write" ON public.wbs_rebalance_log;
CREATE POLICY "wbs_rebalance_log service write" ON public.wbs_rebalance_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 4. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS タスク動的再分担 (Rebalance) Phase 1',
  $md$Win版#132 part 17。ユーザー要請「instance 毎タスク偏り / idle instance / 滞留タスク自担当変更」を受けた 3-Phase 計画 (Phase 1: log table + wbs.rebalance_suggest + wbs.claim_task / Phase 2: session-start hook auto-suggest / Phase 3: KPI dashboard) の Phase 1 基盤。stale_score スコアリング (期限ペナルティ + 進捗停滞 + half-way + priority bonus + loop 防止) + 抑制ルール (1 session 最大 2 claim / 7 日 cooldown / completed protect / IPO 専決保護 / PS 専任保護) + audit log。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
