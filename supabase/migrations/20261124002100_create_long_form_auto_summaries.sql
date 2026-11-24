-- Batch 65 (#2642): 長文コンテンツのバックグラウンド自動要約と要約プレビュー機能
-- long_form_documents の保存時に AFTER INSERT OR UPDATE トリガーで long_form_summaries へ
-- 自動キューイング（レート制限時は rate_limited + retry_after_seconds）を行う。

CREATE TABLE IF NOT EXISTS public.long_form_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 1 AND 200),
  body_text text NOT NULL CHECK (char_length(body_text) BETWEEN 1 AND 100000),
  char_count integer NOT NULL DEFAULT 0 CHECK (char_count >= 0),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.long_form_summaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL UNIQUE REFERENCES public.long_form_documents(id) ON DELETE CASCADE,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  summary_text text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'queued' CHECK (
    status IN ('queued', 'processing', 'completed', 'rate_limited', 'failed')
  ),
  retry_after_seconds integer NOT NULL DEFAULT 0 CHECK (retry_after_seconds >= 0),
  model_name text NOT NULL DEFAULT 'extractive-local-v1',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_long_form_documents_user_created
  ON public.long_form_documents (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_long_form_summaries_user_status_created
  ON public.long_form_summaries (user_id, status, created_at DESC);

ALTER TABLE public.long_form_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.long_form_summaries ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.long_form_documents FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.long_form_documents
  TO authenticated;
GRANT ALL ON TABLE public.long_form_documents TO service_role;

REVOKE ALL ON TABLE public.long_form_summaries FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.long_form_summaries
  TO authenticated;
GRANT ALL ON TABLE public.long_form_summaries TO service_role;

-- long_form_documents RLS policies
DROP POLICY IF EXISTS long_form_documents_owner_select
  ON public.long_form_documents;
CREATE POLICY long_form_documents_owner_select
  ON public.long_form_documents
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_documents_owner_insert
  ON public.long_form_documents;
CREATE POLICY long_form_documents_owner_insert
  ON public.long_form_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_documents_owner_update
  ON public.long_form_documents;
CREATE POLICY long_form_documents_owner_update
  ON public.long_form_documents
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_documents_owner_delete
  ON public.long_form_documents;
CREATE POLICY long_form_documents_owner_delete
  ON public.long_form_documents
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- long_form_summaries RLS policies
DROP POLICY IF EXISTS long_form_summaries_owner_select
  ON public.long_form_summaries;
CREATE POLICY long_form_summaries_owner_select
  ON public.long_form_summaries
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_summaries_owner_insert
  ON public.long_form_summaries;
CREATE POLICY long_form_summaries_owner_insert
  ON public.long_form_summaries
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_summaries_owner_update
  ON public.long_form_summaries;
CREATE POLICY long_form_summaries_owner_update
  ON public.long_form_summaries
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS long_form_summaries_owner_delete
  ON public.long_form_summaries;
CREATE POLICY long_form_summaries_owner_delete
  ON public.long_form_summaries
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.guard_long_form_document()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_service boolean;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for long_form_documents';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'user_id must match authenticated caller';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, user_id, created_at cannot be modified';
      END IF;
    END IF;
  END IF;

  NEW.char_count := char_length(NEW.body_text);
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_long_form_document
  ON public.long_form_documents;
CREATE TRIGGER trg_guard_long_form_document
  BEFORE INSERT OR UPDATE
  ON public.long_form_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_long_form_document();

CREATE OR REPLACE FUNCTION public.guard_long_form_summary()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_service boolean;
  v_doc_owner uuid;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for long_form_summaries';
    END IF;

    SELECT d.user_id
      INTO v_doc_owner
    FROM public.long_form_documents d
    WHERE d.id = NEW.document_id
    LIMIT 1;

    IF v_doc_owner IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'document_id must belong to authenticated caller';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'user_id must match authenticated caller';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.document_id IS DISTINCT FROM OLD.document_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, user_id, document_id, created_at cannot be modified';
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_long_form_summary
  ON public.long_form_summaries;
CREATE TRIGGER trg_guard_long_form_summary
  BEFORE INSERT OR UPDATE
  ON public.long_form_summaries
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_long_form_summary();

CREATE OR REPLACE FUNCTION public.enqueue_long_form_summary_on_save()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $enqueue$
DECLARE
  v_recent_jobs integer;
  v_status text;
  v_retry_after integer;
BEGIN
  IF char_length(NEW.body_text) < 400 THEN
    RETURN NEW;
  END IF;

  SELECT count(*)::integer
    INTO v_recent_jobs
  FROM public.long_form_summaries s
  WHERE s.user_id = NEW.user_id
    AND s.document_id <> NEW.id
    AND s.created_at >= timezone('utc', now()) - interval '1 hour';

  IF v_recent_jobs >= 10 THEN
    v_status := 'rate_limited';
    v_retry_after := 300;
  ELSE
    v_status := 'queued';
    v_retry_after := 0;
  END IF;

  INSERT INTO public.long_form_summaries (
    document_id,
    user_id,
    summary_text,
    status,
    retry_after_seconds,
    model_name
  )
  VALUES (
    NEW.id,
    NEW.user_id,
    '',
    v_status,
    v_retry_after,
    'extractive-local-v1'
  )
  ON CONFLICT (document_id) DO UPDATE
    SET status = EXCLUDED.status,
        retry_after_seconds = EXCLUDED.retry_after_seconds,
        updated_at = timezone('utc', now());

  RETURN NEW;
END;
$enqueue$;

DROP TRIGGER IF EXISTS trg_enqueue_long_form_summary_on_save
  ON public.long_form_documents;
CREATE TRIGGER trg_enqueue_long_form_summary_on_save
  AFTER INSERT OR UPDATE OF body_text
  ON public.long_form_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_long_form_summary_on_save();
