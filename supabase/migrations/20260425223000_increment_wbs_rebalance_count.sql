-- Add RPC used by tools-hub wbs.claim_task.
-- Keeps rebalance_count updates idempotent and service-role friendly.

CREATE OR REPLACE FUNCTION public.increment_wbs_rebalance_count(p_task_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.wbs_tasks
  SET rebalance_count = COALESCE(rebalance_count, 0) + 1
  WHERE id = p_task_id;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_wbs_rebalance_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_wbs_rebalance_count(uuid) TO service_role;
