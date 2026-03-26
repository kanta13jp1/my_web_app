-- Schedule タスク実行ログテーブル
-- Claude Code Schedule の各タスク実行結果を記録し、
-- 管理者ダッシュボード (ScheduleTaskMonitorCard) から確認できるようにする。
CREATE TABLE IF NOT EXISTS schedule_task_runs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id text NOT NULL,
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'success', 'error', 'skipped')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  summary text,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- task_id + started_at で最新の実行を高速に取得
CREATE INDEX IF NOT EXISTS idx_schedule_task_runs_task_started
  ON schedule_task_runs (task_id, started_at DESC);

-- ステータス別のフィルタリング用
CREATE INDEX IF NOT EXISTS idx_schedule_task_runs_status
  ON schedule_task_runs (status);

-- RLS: service_role のみアクセス可能
ALTER TABLE schedule_task_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_full_access_schedule_task_runs"
  ON schedule_task_runs
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 管理者 (authenticated) も読み取り可能にする
CREATE POLICY "authenticated_read_schedule_task_runs"
  ON schedule_task_runs
  FOR SELECT
  USING (auth.role() = 'authenticated');

COMMENT ON TABLE schedule_task_runs IS 'Claude Code Schedule タスクの実行ログ';
COMMENT ON COLUMN schedule_task_runs.task_id IS 'タスク識別子 (例: daily-report, cs-check)';
COMMENT ON COLUMN schedule_task_runs.status IS '実行状態: running/success/error/skipped';
COMMENT ON COLUMN schedule_task_runs.summary IS '実行結果の要約テキスト';
