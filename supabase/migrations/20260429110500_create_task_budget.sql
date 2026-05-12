-- PLATFORM #6: task_budget cost guard.
-- Scope hierarchy: month -> instance -> ef / gha.

CREATE TABLE IF NOT EXISTS task_budget (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('ef', 'gha', 'instance', 'month')),
  scope_id text NOT NULL,
  limit_usd numeric(10, 2) NOT NULL,
  spent_usd numeric(12, 8) NOT NULL DEFAULT 0,
  reset_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scope, scope_id)
);

ALTER TABLE task_budget ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS task_budget_service_role ON task_budget;
CREATE POLICY task_budget_service_role ON task_budget
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE INDEX IF NOT EXISTS task_budget_scope_reset_idx
  ON task_budget (scope, reset_at);

DROP TRIGGER IF EXISTS update_task_budget_updated_at ON task_budget;
CREATE TRIGGER update_task_budget_updated_at
  BEFORE UPDATE ON task_budget
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION record_task_budget_spend(
  p_scope text,
  p_scope_id text,
  p_amount_usd numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'record_task_budget_spend requires service_role';
  END IF;

  INSERT INTO task_budget (scope, scope_id, limit_usd, spent_usd, reset_at)
  VALUES (
    p_scope,
    p_scope_id,
    CASE
      WHEN p_scope = 'month' THEN 5000.00
      WHEN p_scope = 'instance' THEN 400.00
      WHEN p_scope = 'ef' THEN 50.00
      WHEN p_scope = 'gha' THEN 20.00
      ELSE 20.00
    END,
    GREATEST(p_amount_usd, 0),
    date_trunc('month', now()) + interval '1 month'
  )
  ON CONFLICT (scope, scope_id)
  DO UPDATE SET
    spent_usd = task_budget.spent_usd + GREATEST(p_amount_usd, 0),
    updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.record_task_budget_spend(text, text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_task_budget_spend(text, text, numeric) TO service_role;

INSERT INTO task_budget (scope, scope_id, limit_usd, reset_at) VALUES
  ('month', '2026-04', 5000.00, '2026-05-01T00:00:00Z'),
  ('instance', 'win', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps1', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps2', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps3', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps4', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps5', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'ps6', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'vscode', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'codex1', 400.00, '2026-05-01T00:00:00Z'),
  ('instance', 'codex2', 400.00, '2026-05-01T00:00:00Z'),
  ('ef', 'ai-hub', 50.00, '2026-05-01T00:00:00Z'),
  ('ef', 'memory-search-hub', 50.00, '2026-05-01T00:00:00Z'),
  ('gha', 'cs-check', 20.00, '2026-05-01T00:00:00Z'),
  ('gha', 'daily-report', 20.00, '2026-05-01T00:00:00Z'),
  ('gha', 'ai-university-update', 20.00, '2026-05-01T00:00:00Z'),
  ('gha', 'blog-engagement', 20.00, '2026-05-01T00:00:00Z')
ON CONFLICT (scope, scope_id) DO NOTHING;

COMMENT ON TABLE task_budget IS 'PLATFORM #6 cost guard. Tracks scope-level spend for EF, GHA, instance, and month budgets.';
COMMENT ON FUNCTION record_task_budget_spend(text, text, numeric) IS 'Atomically records estimated API spend for a task budget scope.';
