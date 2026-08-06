CREATE TABLE IF NOT EXISTS ai_task_budget_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  objective text NOT NULL,
  budget_tokens integer NOT NULL CHECK (budget_tokens >= 20000),
  consumed_tokens integer NOT NULL DEFAULT 0 CHECK (consumed_tokens >= 0),
  effort text NOT NULL DEFAULT 'medium'
    CHECK (effort IN ('low', 'medium', 'high', 'xhigh')),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'running', 'completed', 'budget_safed', 'failed', 'cancelled')),
  progress_percent integer NOT NULL DEFAULT 0
    CHECK (progress_percent >= 0 AND progress_percent <= 100),
  document_count integer NOT NULL DEFAULT 0 CHECK (document_count >= 0),
  summary text NOT NULL DEFAULT '',
  artifact jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS ai_task_budget_job_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL REFERENCES ai_task_budget_jobs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  step_index integer NOT NULL CHECK (step_index > 0),
  title text NOT NULL,
  status text NOT NULL CHECK (status IN ('completed', 'skipped', 'budget_safed')),
  input_tokens integer NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens integer NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (job_id, step_index)
);

ALTER TABLE ai_task_budget_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_task_budget_job_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_task_budget_jobs_owner_select ON ai_task_budget_jobs;
CREATE POLICY ai_task_budget_jobs_owner_select ON ai_task_budget_jobs
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS ai_task_budget_jobs_owner_insert ON ai_task_budget_jobs;
CREATE POLICY ai_task_budget_jobs_owner_insert ON ai_task_budget_jobs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS ai_task_budget_jobs_owner_update ON ai_task_budget_jobs;
CREATE POLICY ai_task_budget_jobs_owner_update ON ai_task_budget_jobs
  FOR UPDATE
  USING (auth.uid() = user_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS ai_task_budget_steps_owner_select ON ai_task_budget_job_steps;
CREATE POLICY ai_task_budget_steps_owner_select ON ai_task_budget_job_steps
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS ai_task_budget_steps_owner_insert ON ai_task_budget_job_steps;
CREATE POLICY ai_task_budget_steps_owner_insert ON ai_task_budget_job_steps
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

CREATE INDEX IF NOT EXISTS ai_task_budget_jobs_user_updated_idx
  ON ai_task_budget_jobs (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS ai_task_budget_steps_job_idx
  ON ai_task_budget_job_steps (job_id, step_index);

DROP TRIGGER IF EXISTS update_ai_task_budget_jobs_updated_at ON ai_task_budget_jobs;
CREATE TRIGGER update_ai_task_budget_jobs_updated_at
  BEFORE UPDATE ON ai_task_budget_jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE ai_task_budget_jobs IS
  'User-scoped autonomous document aggregation jobs with an explicit token budget.';
COMMENT ON TABLE ai_task_budget_job_steps IS
  'Per-step progress and token accounting for ai_task_budget_jobs.';
