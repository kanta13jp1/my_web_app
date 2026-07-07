-- Issue #1209: generated UI sandbox backend capability boundary.
--
-- The Flutter Web preview runs in a network-denied opaque-origin iframe. This
-- table records the matching server-side capability boundary so future backend
-- connectors cannot accidentally widen generated UI previews into Auth, secret,
-- write, or external-share access.

CREATE TABLE IF NOT EXISTS public.generated_ui_sandbox_capability_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sandbox_id text NOT NULL DEFAULT 'ai-chat-generated-ui',
  role_name text NOT NULL DEFAULT 'generated_ui_sandbox',
  allowed_scopes text[] NOT NULL DEFAULT ARRAY['read']::text[],
  backend_access_allowed boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT generated_ui_sandbox_capability_role_check
    CHECK (role_name = 'generated_ui_sandbox'),
  CONSTRAINT generated_ui_sandbox_capability_scopes_check
    CHECK (allowed_scopes <@ ARRAY['read']::text[]),
  CONSTRAINT generated_ui_sandbox_capability_backend_check
    CHECK (backend_access_allowed = false)
);

CREATE UNIQUE INDEX IF NOT EXISTS generated_ui_sandbox_capability_user_sandbox_key
  ON public.generated_ui_sandbox_capability_grants(user_id, sandbox_id);

CREATE INDEX IF NOT EXISTS generated_ui_sandbox_capability_user_created_idx
  ON public.generated_ui_sandbox_capability_grants(user_id, created_at DESC);

ALTER TABLE public.generated_ui_sandbox_capability_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS generated_ui_sandbox_capability_select_own
  ON public.generated_ui_sandbox_capability_grants;
DROP POLICY IF EXISTS generated_ui_sandbox_capability_insert_own
  ON public.generated_ui_sandbox_capability_grants;
DROP POLICY IF EXISTS generated_ui_sandbox_capability_update_own
  ON public.generated_ui_sandbox_capability_grants;
DROP POLICY IF EXISTS generated_ui_sandbox_capability_delete_own
  ON public.generated_ui_sandbox_capability_grants;

CREATE POLICY generated_ui_sandbox_capability_select_own
  ON public.generated_ui_sandbox_capability_grants
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY generated_ui_sandbox_capability_insert_own
  ON public.generated_ui_sandbox_capability_grants
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY generated_ui_sandbox_capability_update_own
  ON public.generated_ui_sandbox_capability_grants
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY generated_ui_sandbox_capability_delete_own
  ON public.generated_ui_sandbox_capability_grants
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.generated_ui_sandbox_capability_grants
  TO authenticated;

COMMENT ON TABLE public.generated_ui_sandbox_capability_grants IS
  'Issue #1209 generated UI sandbox capability grants. Constraints force generated_ui_sandbox to read-only and backend_access_allowed=false.';
COMMENT ON COLUMN public.generated_ui_sandbox_capability_grants.allowed_scopes IS
  'Hard-limited to read by CHECK constraint; generated UI previews must not receive Auth, secret, write, send, or external-share capability.';
COMMENT ON COLUMN public.generated_ui_sandbox_capability_grants.backend_access_allowed IS
  'Always false for generated UI previews; the iframe boundary remains network-denied and backend-denied by default.';
