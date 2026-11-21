-- Issue #1380: deny missing role claims and remove unintended RPC grants.
BEGIN;
CREATE OR REPLACE FUNCTION public.record_task_budget_spend(
  p_scope text, p_scope_id text, p_amount_usd numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'record_task_budget_spend requires service_role'
      USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.task_budget (scope, scope_id, limit_usd, spent_usd, reset_at)
  VALUES (
    p_scope, p_scope_id,
    CASE WHEN p_scope = 'month' THEN 5000.00
         WHEN p_scope = 'instance' THEN 400.00
         WHEN p_scope = 'ef' THEN 50.00
         WHEN p_scope = 'gha' THEN 20.00 ELSE 20.00 END,
    GREATEST(p_amount_usd, 0),
    pg_catalog.date_trunc('month', pg_catalog.now()) + interval '1 month'
  )
  ON CONFLICT (scope, scope_id) DO UPDATE
    SET spent_usd = public.task_budget.spent_usd + GREATEST(p_amount_usd, 0),
        updated_at = pg_catalog.now();
END;
$$;
REVOKE ALL ON FUNCTION public.record_task_budget_spend(text, text, numeric)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_task_budget_spend(text, text, numeric)
  TO service_role;
COMMIT;
