-- Win版#132 part 19: user タスク進捗報告 + NotebookLM 蓄積基盤
--
-- 契機: ユーザー要請「user タスクの実施完了/状況を報告できる UI + NotebookLM に蓄積して
-- 具体的手順を分析」
--
-- 設計:
--   - wbs_user_task_reports テーブル (時系列の進捗報告 / NotebookLM 蓄積用)
--   - 各 report = task_id + progress + status + report_text + reporter
--   - NotebookLM へは GHA cron で md snapshot 化して commit (notebooklm-user-tasks-sync.yml)

-- ============================================================
-- 1. wbs_user_task_reports テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wbs_user_task_reports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         uuid REFERENCES public.wbs_tasks(id) ON DELETE CASCADE,
  reporter        text NOT NULL DEFAULT 'user',  -- 'user' / 'ai-agent' / etc
  progress        int CHECK (progress BETWEEN 0 AND 100),
  status          text CHECK (status IN ('pending', 'in_progress', 'completed', 'blocked')),
  report_text     text,                          -- ユーザーが書く実施状況コメント (markdown OK)
  blockers        text,                          -- 詰まりポイント (NotebookLM が分析対象)
  next_action     text,                          -- 次の具体的アクション
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wbs_user_task_reports_task
  ON public.wbs_user_task_reports (task_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wbs_user_task_reports_recent
  ON public.wbs_user_task_reports (created_at DESC);

COMMENT ON TABLE public.wbs_user_task_reports IS
  'user instance タスクの進捗報告履歴 (時系列) / NotebookLM 蓄積対象 / docs/user-tasks-snapshot.md に export';
COMMENT ON COLUMN public.wbs_user_task_reports.report_text IS
  'ユーザーが書く実施状況コメント (markdown OK) / NotebookLM が分析して具体的手順抽出';
COMMENT ON COLUMN public.wbs_user_task_reports.blockers IS
  '詰まりポイント / 不明点 / NotebookLM が解決手順を suggest';

-- ============================================================
-- 2. RLS (public read / service_role write)
-- ============================================================
ALTER TABLE public.wbs_user_task_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wbs_user_task_reports public read" ON public.wbs_user_task_reports;
CREATE POLICY "wbs_user_task_reports public read" ON public.wbs_user_task_reports
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "wbs_user_task_reports service write" ON public.wbs_user_task_reports;
CREATE POLICY "wbs_user_task_reports service write" ON public.wbs_user_task_reports
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 3. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'user タスク進捗報告 + NotebookLM 蓄積基盤 (Win#132 part 19)',
  $md$ユーザー要請「user タスクの実施完了/状況報告 UI + NotebookLM 蓄積で具体的手順分析」を受けた基盤テーブル。wbs_user_task_reports = 時系列の進捗報告 (task_id / progress / status / report_text / blockers / next_action / metadata)。後続: tools-hub 2 actions (wbs.user_task_report 進捗報告 / wbs.export_user_tasks_md NotebookLM 用 md export) + GHA notebooklm-user-tasks-sync.yml (週次で docs/user-tasks-snapshot.md commit) + VSCode 担当 UI cross-instance-pr。$md$,
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
