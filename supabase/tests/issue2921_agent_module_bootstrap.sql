-- Minimal predecessor schema for the Issue #2921 Testcontainers contract.
-- The shared fixture already provides auth.users, auth.uid(), and roles.

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN NULLIF(current_setting('request.jwt.claims', true), '') IS NULL
      THEN '{}'::jsonb
    ELSE current_setting('request.jwt.claims', true)::jsonb
  END;
$$;

GRANT EXECUTE ON FUNCTION auth.jwt() TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slug text NOT NULL,
  display_name text NOT NULL,
  role_title text NOT NULL,
  department text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (user_id, slug)
);

CREATE TABLE IF NOT EXISTS public.agent_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  supervisor_agent_id uuid NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
  assignee_agent_id uuid NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'in_progress', 'completed', 'cancelled')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high')),
  task_type text NOT NULL DEFAULT 'delegated_action',
  source text NOT NULL DEFAULT 'manual_delegate',
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Agents select own org" ON public.agents
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent tasks select own org" ON public.agent_tasks
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent tasks insert own org" ON public.agent_tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent tasks update own org" ON public.agent_tasks
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent tasks delete own org" ON public.agent_tasks
  FOR DELETE USING (auth.uid() = user_id);

GRANT SELECT ON TABLE public.agents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.agent_tasks TO authenticated;
GRANT ALL ON TABLE public.agents, public.agent_tasks TO service_role;

INSERT INTO auth.users (id)
VALUES
  ('00000000-0000-4000-8000-000000002921'),
  ('00000000-0000-4000-8000-000000002922')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.agents (
  id,
  user_id,
  slug,
  display_name,
  role_title,
  department,
  status
)
VALUES
  (
    '00000000-0000-4000-8000-00000000a921',
    '00000000-0000-4000-8000-000000002921',
    'front-office',
    'Front Office Agent',
    'Customer Intake',
    'front_office',
    'active'
  ),
  (
    '00000000-0000-4000-8000-00000000b921',
    '00000000-0000-4000-8000-000000002921',
    'management',
    'Management Agent',
    'Overall Manager',
    'management',
    'active'
  ),
  (
    '00000000-0000-4000-8000-00000000c921',
    '00000000-0000-4000-8000-000000002921',
    'unassigned-front',
    'Unassigned Front Agent',
    'Customer Intake',
    'front_office',
    'active'
  ),
  (
    '00000000-0000-4000-8000-00000000d921',
    '00000000-0000-4000-8000-000000002922',
    'outside-management',
    'Outside Management Agent',
    'Overall Manager',
    'management',
    'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.agent_tasks (
  id,
  user_id,
  supervisor_agent_id,
  assignee_agent_id,
  title,
  description,
  metadata
)
VALUES (
  '00000000-0000-4000-8000-00000000e921',
  '00000000-0000-4000-8000-000000002921',
  '00000000-0000-4000-8000-00000000b921',
  '00000000-0000-4000-8000-00000000a921',
  'Legacy owner-managed task',
  'Must remain compatible with the existing owner UI.',
  '{"fixture":"issue-2921"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;
