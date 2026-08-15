-- Staging-only bootstrap for the isolated MUSUBI validation project.
-- The production application already owns its admin helper. This migration is
-- intentionally excluded from supabase/migrations so it can never be pushed by
-- the production deployment workflow.

CREATE OR REPLACE FUNCTION public.is_user_admin(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT false;
$$;

COMMENT ON FUNCTION public.is_user_admin(uuid) IS
  'Staging bootstrap: MUSUBI moderation has no application admins by default.';
