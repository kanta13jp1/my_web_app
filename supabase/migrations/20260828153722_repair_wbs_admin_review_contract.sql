-- Issue #4956: repair the WBS admin authorization and review-ready state.
--
-- user_profiles.id is a profile row identifier. Supabase auth identities are
-- stored in user_profiles.user_id and must be checked through the hardened
-- SECURITY DEFINER helper so the user_profiles RLS policy cannot recurse.

DROP POLICY IF EXISTS "wbs_milestones_admin_write"
  ON public.wbs_milestones;
CREATE POLICY "wbs_milestones_admin_write"
  ON public.wbs_milestones
  FOR ALL
  TO authenticated
  USING ((SELECT public.is_user_admin((SELECT auth.uid()))))
  WITH CHECK ((SELECT public.is_user_admin((SELECT auth.uid()))));

DROP POLICY IF EXISTS "wbs_tasks_admin_write"
  ON public.wbs_tasks;
CREATE POLICY "wbs_tasks_admin_write"
  ON public.wbs_tasks
  FOR ALL
  TO authenticated
  USING ((SELECT public.is_user_admin((SELECT auth.uid()))))
  WITH CHECK ((SELECT public.is_user_admin((SELECT auth.uid()))));

-- OPEN GitHub Issues may reach the explicit review-ready state
-- (in_progress / 100 / requested), but cannot become completed until an
-- approved review status or an explicit human manual override is recorded.
CREATE OR REPLACE FUNCTION public.wbs_guard_open_github_issue_completion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.github_issue_number IS NOT NULL
     AND upper(
       coalesce(nullif(btrim(NEW.github_issue_state), ''), 'OPEN')
     ) <> 'CLOSED'
     AND lower(coalesce(NEW.ai_review_status, 'pending')) NOT IN
       ('approved', 'verified', 'passed', 'manual_override') THEN
    IF NEW.status = 'completed' THEN
      NEW.status := 'in_progress';
    END IF;

    IF lower(coalesce(NEW.ai_review_status, 'pending')) = 'pending'
       AND coalesce(NEW.progress, 0) >= 100 THEN
      -- This guard sorts before the legacy wbs_request_ai_review trigger.
      -- Normalize here so trigger ordering cannot erase auto-review readiness.
      NEW.status := 'in_progress';
      NEW.progress := 100;
      NEW.ai_review_status := 'requested';
    ELSIF lower(coalesce(NEW.ai_review_status, 'pending')) = 'requested' THEN
      NEW.status := 'in_progress';
      NEW.progress := 100;
    ELSIF coalesce(NEW.progress, 0) >= 100 THEN
      NEW.progress := 99;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS wbs_open_github_issue_completion_guard
  ON public.wbs_tasks;
CREATE TRIGGER wbs_open_github_issue_completion_guard
  BEFORE INSERT OR UPDATE ON public.wbs_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.wbs_guard_open_github_issue_completion();

COMMENT ON FUNCTION public.wbs_guard_open_github_issue_completion() IS
  'Keeps linked Issues incomplete unless explicitly CLOSED while preserving '
  'explicit review-ready '
  '(in_progress/100/requested) state, including pending-to-requested auto '
  'normalization before the legacy review trigger; manual_override is an '
  'explicit human administrator decision and is never assigned by this trigger.';

COMMENT ON COLUMN public.wbs_tasks.ai_review_status IS
  'pending -> requested at review readiness -> approved/rejected; '
  'manual_override is reserved for an explicit human administrator decision.';
