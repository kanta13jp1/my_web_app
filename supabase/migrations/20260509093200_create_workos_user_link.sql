-- Issue #1577 Phase A: map WorkOS AuthKit users to Supabase Auth users.

CREATE TABLE IF NOT EXISTS public.workos_user_link (
  supabase_user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  workos_user_id text NOT NULL UNIQUE,
  workos_org_id text,
  linked_at timestamptz NOT NULL DEFAULT now(),
  last_verified_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS workos_user_link_org_idx
  ON public.workos_user_link (workos_org_id)
  WHERE workos_org_id IS NOT NULL;

ALTER TABLE public.workos_user_link ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'workos_user_link'
      AND policyname = 'workos_link_owner_select'
  ) THEN
    CREATE POLICY "workos_link_owner_select"
      ON public.workos_user_link
      FOR SELECT
      USING (auth.uid() = supabase_user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'workos_user_link'
      AND policyname = 'workos_link_service_role_write'
  ) THEN
    CREATE POLICY "workos_link_service_role_write"
      ON public.workos_user_link
      FOR ALL
      USING (auth.role() = 'service_role')
      WITH CHECK (auth.role() = 'service_role');
  END IF;
END $$;

COMMENT ON TABLE public.workos_user_link IS
  'Standalone Connect mapping from WorkOS AuthKit users to Supabase Auth users.';
COMMENT ON COLUMN public.workos_user_link.supabase_user_id IS
  'Local Supabase Auth user that owns the WorkOS AuthKit link.';
COMMENT ON COLUMN public.workos_user_link.workos_user_id IS
  'WorkOS AuthKit user identifier from verified JWT subject.';
COMMENT ON COLUMN public.workos_user_link.workos_org_id IS
  'Optional WorkOS organization identifier for org-aware MCP authorization.';
