-- PS#4 S49: user_task_reports テーブル + NotebookLM 用 daily_report カラム (2026-04-25)
-- ユーザータスクの進捗報告・完了記録を蓄積。GHA がこのデータを元に NotebookLM 用 MD を生成。

-- ============================================================
-- 1. user_task_reports テーブル
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_task_reports (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id       uuid NOT NULL REFERENCES public.wbs_tasks(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'in_progress'
                  CHECK (status IN ('not_started', 'in_progress', 'completed', 'blocked', 'delegated')),
  progress      integer NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  report_text   text,                          -- ユーザーの実施状況コメント
  next_action   text,                          -- 次のアクション
  blockers      text,                          -- 障害・ブロッカー
  reported_by   text NOT NULL DEFAULT 'user',
  notebooklm_synced boolean DEFAULT false,    -- NotebookLM にソース追加済みフラグ
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- インデックス
CREATE INDEX IF NOT EXISTS user_task_reports_task_id_idx
  ON public.user_task_reports (task_id);
CREATE INDEX IF NOT EXISTS user_task_reports_created_at_idx
  ON public.user_task_reports (created_at DESC);

-- RLS
ALTER TABLE public.user_task_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read_user_task_reports"
  ON public.user_task_reports FOR SELECT USING (true);

CREATE POLICY "service_role_write_user_task_reports"
  ON public.user_task_reports FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================================
-- 2. wbs_tasks に notebooklm_note カラム追加 (AI が生成した手順メモ)
-- ============================================================

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS notebooklm_note text,
  ADD COLUMN IF NOT EXISTS notebooklm_synced_at timestamptz;

COMMENT ON COLUMN public.wbs_tasks.notebooklm_note IS
  'NotebookLM が生成した具体的手順・留意事項 (自動更新)';
COMMENT ON COLUMN public.wbs_tasks.notebooklm_synced_at IS
  '最後に NotebookLM へソース追加した日時';

-- ============================================================
-- 3. 実績記録
-- ============================================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'user_task_reports テーブル + NotebookLM 連携基盤 (PS#4 S49)',
  'user_task_reports (進捗/報告/ブロッカー/notebooklm_synced) + wbs_tasks.notebooklm_note カラム追加 + ' ||
  'UI (user-tasks ページ) からの進捗報告 → NotebookLM 蓄積フロー基盤',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
