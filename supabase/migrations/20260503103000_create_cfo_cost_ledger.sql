-- Issue #1669: CFO cost ledger and monthly budget summary.
-- This is intentionally separate from cfo_assets: assets track balance sheet
-- state, while this ledger tracks structured monthly cost decisions.

CREATE TABLE IF NOT EXISTS public.cfo_cost_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item text NOT NULL,
  category text NOT NULL DEFAULT 'other',
  amount_jpy bigint NOT NULL CHECK (amount_jpy >= 0),
  incurred_on date NOT NULL DEFAULT current_date,
  note text NOT NULL DEFAULT '',
  cost_type text NOT NULL DEFAULT 'variable'
    CHECK (cost_type IN ('fixed', 'variable')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cfo_monthly_budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month text NOT NULL CHECK (month ~ '^[0-9]{4}-[0-9]{2}$'),
  budget_jpy bigint NOT NULL CHECK (budget_jpy >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, month)
);

CREATE INDEX IF NOT EXISTS idx_cfo_cost_entries_user_month
  ON public.cfo_cost_entries (user_id, incurred_on DESC);

CREATE INDEX IF NOT EXISTS idx_cfo_cost_entries_user_category
  ON public.cfo_cost_entries (user_id, category);

CREATE INDEX IF NOT EXISTS idx_cfo_monthly_budgets_user_month
  ON public.cfo_monthly_budgets (user_id, month);

CREATE OR REPLACE FUNCTION public.set_cfo_cost_ledger_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cfo_cost_entries_updated_at
  ON public.cfo_cost_entries;
CREATE TRIGGER trg_cfo_cost_entries_updated_at
  BEFORE UPDATE ON public.cfo_cost_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.set_cfo_cost_ledger_updated_at();

DROP TRIGGER IF EXISTS trg_cfo_monthly_budgets_updated_at
  ON public.cfo_monthly_budgets;
CREATE TRIGGER trg_cfo_monthly_budgets_updated_at
  BEFORE UPDATE ON public.cfo_monthly_budgets
  FOR EACH ROW
  EXECUTE FUNCTION public.set_cfo_cost_ledger_updated_at();

ALTER TABLE public.cfo_cost_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cfo_monthly_budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own_cfo_cost_entries"
  ON public.cfo_cost_entries;
CREATE POLICY "users_select_own_cfo_cost_entries"
  ON public.cfo_cost_entries
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_insert_own_cfo_cost_entries"
  ON public.cfo_cost_entries;
CREATE POLICY "users_insert_own_cfo_cost_entries"
  ON public.cfo_cost_entries
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_update_own_cfo_cost_entries"
  ON public.cfo_cost_entries;
CREATE POLICY "users_update_own_cfo_cost_entries"
  ON public.cfo_cost_entries
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_delete_own_cfo_cost_entries"
  ON public.cfo_cost_entries;
CREATE POLICY "users_delete_own_cfo_cost_entries"
  ON public.cfo_cost_entries
  FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_select_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets;
CREATE POLICY "users_select_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_insert_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets;
CREATE POLICY "users_insert_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_update_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets;
CREATE POLICY "users_update_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_delete_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets;
CREATE POLICY "users_delete_own_cfo_monthly_budgets"
  ON public.cfo_monthly_budgets
  FOR DELETE
  USING (auth.uid() = user_id);
