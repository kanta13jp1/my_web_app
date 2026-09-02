-- Minimal predecessor schema for the Issue #4956 runtime contract. The shared
-- Testcontainers fixture already supplies wbs_tasks and Supabase auth helpers.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE NOT NULL,
  is_admin boolean NOT NULL DEFAULT false
);

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS progress integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS github_issue_number integer,
  ADD COLUMN IF NOT EXISTS github_issue_state text,
  ADD COLUMN IF NOT EXISTS ai_review_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS public.wbs_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  target_date date NOT NULL
);

ALTER TABLE public.wbs_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wbs_milestones ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.wbs_tasks, public.wbs_milestones
  TO authenticated;

CREATE OR REPLACE FUNCTION public.is_user_admin(check_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT profile.is_admin
       FROM public.user_profiles AS profile
      WHERE profile.user_id = check_user_id),
    false
  );
$$;

-- Recreate the broken predecessor policies to prove the repair replaces them.
DROP POLICY IF EXISTS "wbs_tasks_admin_write" ON public.wbs_tasks;
CREATE POLICY "wbs_tasks_admin_write"
  ON public.wbs_tasks
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

DROP POLICY IF EXISTS "wbs_milestones_admin_write" ON public.wbs_milestones;
CREATE POLICY "wbs_milestones_admin_write"
  ON public.wbs_milestones
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

CREATE OR REPLACE FUNCTION public.wbs_guard_open_github_issue_completion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.github_issue_number IS NOT NULL
     AND upper(coalesce(NEW.github_issue_state, 'OPEN')) = 'OPEN'
     AND lower(coalesce(NEW.ai_review_status, 'pending')) NOT IN
       ('approved', 'verified', 'passed', 'manual_override') THEN
    IF coalesce(NEW.progress, 0) >= 100 THEN
      NEW.progress := 99;
    END IF;
    IF NEW.status = 'completed' THEN
      NEW.status := 'in_progress';
    END IF;
    IF NEW.ai_review_status = 'requested' THEN
      NEW.ai_review_status := 'pending';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Install the production predecessor auto-request trigger too. PostgreSQL runs
-- same-kind triggers alphabetically, so the OPEN-Issue guard executes first.
CREATE OR REPLACE FUNCTION public.wbs_request_ai_review_on_complete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.progress = 100
     AND OLD.progress < 100
     AND NEW.ai_review_status = 'pending' THEN
    NEW.ai_review_status := 'requested';
    NEW.status := 'in_progress';
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

DROP TRIGGER IF EXISTS wbs_request_ai_review ON public.wbs_tasks;
CREATE TRIGGER wbs_request_ai_review
  BEFORE UPDATE OF progress ON public.wbs_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.wbs_request_ai_review_on_complete();

INSERT INTO auth.users (id)
VALUES
  ('00000000-0000-4000-8000-000000004956'),
  ('00000000-0000-4000-8000-000000004957'),
  ('00000000-0000-4000-8000-000000004958')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (id, user_id, is_admin)
VALUES
  (
    '00000000-0000-4000-8000-000000014956',
    '00000000-0000-4000-8000-000000004956',
    true
  ),
  (
    '00000000-0000-4000-8000-000000014957',
    '00000000-0000-4000-8000-000000004957',
    false
  ),
  (
    -- A legacy id lookup would incorrectly grant the non-admin auth identity.
    '00000000-0000-4000-8000-000000004957',
    '00000000-0000-4000-8000-000000004958',
    true
  )
ON CONFLICT (id) DO UPDATE
SET user_id = EXCLUDED.user_id,
    is_admin = EXCLUDED.is_admin;

INSERT INTO public.wbs_tasks (
  id,
  title,
  status,
  owner_instance,
  progress,
  github_issue_number,
  github_issue_state,
  ai_review_status
)
VALUES (
  '00000000-0000-4000-8000-000000024956',
  'Issue #4956 review contract fixture',
  'in_progress',
  'Codex #1',
  0,
  4956,
  'OPEN',
  'pending'
)
ON CONFLICT (id) DO NOTHING;
