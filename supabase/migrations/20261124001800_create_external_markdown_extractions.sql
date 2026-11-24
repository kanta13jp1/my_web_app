-- External URL to Markdown & structured JSON extraction records (#2639).

CREATE TABLE IF NOT EXISTS public.external_markdown_extractions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  source_url text NOT NULL CHECK (source_url ~ '^https://[^/\s?#]+'),
  source_title text NOT NULL DEFAULT '',
  markdown_content text NOT NULL DEFAULT '',
  structured_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  extractor_mode text NOT NULL DEFAULT 'stdlib_html'
    CHECK (extractor_mode IN ('stdlib_html', 'firecrawl_v1')),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'completed', 'failed', 'blocked')),
  error_code text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_external_markdown_extractions_user_created
  ON public.external_markdown_extractions (user_id, created_at DESC);

ALTER TABLE public.external_markdown_extractions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.external_markdown_extractions FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.external_markdown_extractions TO authenticated;
GRANT ALL ON TABLE public.external_markdown_extractions TO service_role;

DROP POLICY IF EXISTS "external_markdown_extractions_owner_select"
  ON public.external_markdown_extractions;
CREATE POLICY "external_markdown_extractions_owner_select"
  ON public.external_markdown_extractions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "external_markdown_extractions_owner_insert"
  ON public.external_markdown_extractions;
CREATE POLICY "external_markdown_extractions_owner_insert"
  ON public.external_markdown_extractions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "external_markdown_extractions_owner_update"
  ON public.external_markdown_extractions;
CREATE POLICY "external_markdown_extractions_owner_update"
  ON public.external_markdown_extractions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "external_markdown_extractions_owner_delete"
  ON public.external_markdown_extractions;
CREATE POLICY "external_markdown_extractions_owner_delete"
  ON public.external_markdown_extractions
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "external_markdown_extractions_service_role_all"
  ON public.external_markdown_extractions;
CREATE POLICY "external_markdown_extractions_service_role_all"
  ON public.external_markdown_extractions
  FOR ALL
  TO service_role
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION public.guard_external_markdown_extraction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $guard$
DECLARE
  v_uid uuid := auth.uid();
  v_role text := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    ''
  );
  v_is_privileged boolean := (
    v_role = 'service_role'
    OR (
      session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
      AND v_role NOT IN ('anon', 'authenticated')
    )
  );
BEGIN
  IF NOT v_is_privileged THEN
    IF TG_OP = 'INSERT' THEN
      IF v_uid IS NULL OR NEW.user_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION
          'user_id must match auth.uid() on insert'
          USING ERRCODE = '42501';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
         OR NEW.user_id IS DISTINCT FROM OLD.user_id
         OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION
          'id, user_id, and created_at are immutable'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;

  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_external_markdown_extraction
  ON public.external_markdown_extractions;
CREATE TRIGGER trg_guard_external_markdown_extraction
  BEFORE INSERT OR UPDATE ON public.external_markdown_extractions
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_external_markdown_extraction();

COMMENT ON FUNCTION public.guard_external_markdown_extraction() IS
  'Locks user_id/id/created_at immutable for authenticated callers and refreshes updated_at (#2639).';

COMMENT ON TABLE public.external_markdown_extractions IS
  'Per-user external HTTPS URL to Markdown & structured JSON extraction records (#2639).';
