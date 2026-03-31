-- Schedule Task Runs: Schedule実行ログテーブル
CREATE TABLE IF NOT EXISTS schedule_task_runs (
  id bigserial PRIMARY KEY,
  task_name text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'running', -- running | success | failure | skipped
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  duration_ms integer,
  output text,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- テーブルが既存でも task_name カラムが存在しない場合に追加
ALTER TABLE schedule_task_runs ADD COLUMN IF NOT EXISTS task_name text NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_schedule_task_runs_task_name ON schedule_task_runs(task_name);
CREATE INDEX IF NOT EXISTS idx_schedule_task_runs_status ON schedule_task_runs(status);
CREATE INDEX IF NOT EXISTS idx_schedule_task_runs_started_at ON schedule_task_runs(started_at DESC);

-- Blog Posts: 技術ブログ投稿管理テーブル
CREATE TABLE IF NOT EXISTS blog_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  draft_path text,
  status text NOT NULL DEFAULT 'draft', -- draft | posted | skipped
  target_platforms text[] DEFAULT '{}',
  content_preview text,
  posted_at timestamptz,
  url text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_blog_posts_status ON blog_posts(status);
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at ON blog_posts(created_at DESC);

-- AI Secretary Logs: AI秘書会話ログ
CREATE TABLE IF NOT EXISTS ai_secretary_logs (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  message text NOT NULL,
  context jsonb DEFAULT '{}',
  reply text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_secretary_logs_user_id ON ai_secretary_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_secretary_logs_created_at ON ai_secretary_logs(created_at DESC);

-- Agent Tasks: 仮想組織タスク管理テーブル
CREATE TABLE IF NOT EXISTS agent_tasks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  description text,
  department text,
  priority text DEFAULT 'medium', -- low | medium | high | critical
  assigned_agent_id uuid,
  status text NOT NULL DEFAULT 'pending', -- pending | in_progress | completed | cancelled
  output text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_department ON agent_tasks(department);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_status ON agent_tasks(status);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_assigned_agent ON agent_tasks(assigned_agent_id);

-- Edge Function UI Status: Edge Function の呼び出し状況追跡
CREATE TABLE IF NOT EXISTS edge_function_ui_status (
  id bigserial PRIMARY KEY,
  function_name text UNIQUE NOT NULL,
  has_ui boolean DEFAULT false,
  last_called_at timestamptz,
  call_count integer DEFAULT 0,
  last_error text,
  updated_at timestamptz DEFAULT now()
);

-- Schedule タスク統計を返す RPC 関数
CREATE OR REPLACE FUNCTION get_schedule_task_stats()
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'total_runs', COUNT(*),
    'success_count', COUNT(*) FILTER (WHERE status = 'success'),
    'failure_count', COUNT(*) FILTER (WHERE status = 'failure'),
    'last_run_at', MAX(started_at)
  )
  FROM schedule_task_runs;
$$;

-- RLS ポリシー
ALTER TABLE schedule_task_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_secretary_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE edge_function_ui_status ENABLE ROW LEVEL SECURITY;

-- service_role は全テーブルにフルアクセス (既存ポリシーは DROP して再作成)
DROP POLICY IF EXISTS "service_role_schedule_task_runs" ON schedule_task_runs;
CREATE POLICY "service_role_schedule_task_runs" ON schedule_task_runs FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "service_role_blog_posts" ON blog_posts;
CREATE POLICY "service_role_blog_posts" ON blog_posts FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "service_role_ai_secretary_logs" ON ai_secretary_logs;
CREATE POLICY "service_role_ai_secretary_logs" ON ai_secretary_logs FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "service_role_agent_tasks" ON agent_tasks;
CREATE POLICY "service_role_agent_tasks" ON agent_tasks FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "service_role_edge_function_ui_status" ON edge_function_ui_status;
CREATE POLICY "service_role_edge_function_ui_status" ON edge_function_ui_status FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- ユーザーは自分の秘書ログを読める
DROP POLICY IF EXISTS "users_read_own_secretary_logs" ON ai_secretary_logs;
CREATE POLICY "users_read_own_secretary_logs" ON ai_secretary_logs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_insert_secretary_logs" ON ai_secretary_logs;
CREATE POLICY "users_insert_secretary_logs" ON ai_secretary_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);
