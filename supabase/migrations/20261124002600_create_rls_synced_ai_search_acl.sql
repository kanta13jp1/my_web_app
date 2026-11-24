-- Batch 71 (#2655): External-source ACL / RLS-synced pgvector AI search.
-- Enforces strict PostgreSQL Row Level Security + SECURITY INVOKER search RPC
-- filtering BEFORE vector/text scoring so unauthorized documents never leak
-- into AI prompt contexts.

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.rls_ai_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  external_source_key text NOT NULL CHECK (char_length(trim(external_source_key)) BETWEEN 1 AND 200),
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 1 AND 240),
  content_excerpt text NOT NULL DEFAULT '',
  search_text text NOT NULL DEFAULT '',
  embedding vector(768),
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(content_excerpt, '') || ' ' || coalesce(search_text, '')
    )
  ) STORED,
  acl_version integer NOT NULL DEFAULT 1 CHECK (acl_version >= 1),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_rls_ai_documents_owner_source UNIQUE (owner_user_id, external_source_key)
);

CREATE TABLE IF NOT EXISTS public.rls_ai_document_acls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.rls_ai_documents(id) ON DELETE CASCADE,
  grantee_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  permission_level text NOT NULL DEFAULT 'viewer' CHECK (permission_level IN ('viewer', 'editor')),
  granted_by_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_rls_ai_document_acls_doc_grantee UNIQUE (document_id, grantee_user_id)
);

CREATE INDEX IF NOT EXISTS idx_rls_ai_documents_owner_updated
  ON public.rls_ai_documents (owner_user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_rls_ai_documents_search_vector
  ON public.rls_ai_documents USING gin (search_vector);

CREATE INDEX IF NOT EXISTS idx_rls_ai_documents_embedding
  ON public.rls_ai_documents USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rls_ai_document_acls_grantee_active
  ON public.rls_ai_document_acls (grantee_user_id, document_id)
  WHERE revoked_at IS NULL;

-- Non-recursive ownership check prevents 42P17 mutual RLS policy recursion
-- between rls_ai_documents and rls_ai_document_acls.
CREATE OR REPLACE FUNCTION public.is_rls_ai_document_owner(p_document_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rls_ai_documents d
    WHERE d.id = p_document_id
      AND d.owner_user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_rls_ai_document_owner(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_rls_ai_document_owner(uuid) TO authenticated, service_role;

ALTER TABLE public.rls_ai_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rls_ai_document_acls ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.rls_ai_documents FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.rls_ai_documents TO authenticated;
GRANT ALL ON TABLE public.rls_ai_documents TO service_role;

REVOKE ALL ON TABLE public.rls_ai_document_acls FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.rls_ai_document_acls TO authenticated;
GRANT ALL ON TABLE public.rls_ai_document_acls TO service_role;

DROP POLICY IF EXISTS rls_ai_documents_authorized_select
  ON public.rls_ai_documents;
CREATE POLICY rls_ai_documents_authorized_select
  ON public.rls_ai_documents
  FOR SELECT
  TO authenticated
  USING (
    owner_user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.rls_ai_document_acls a
      WHERE a.document_id = rls_ai_documents.id
        AND a.grantee_user_id = auth.uid()
        AND a.revoked_at IS NULL
    )
  );

DROP POLICY IF EXISTS rls_ai_documents_owner_insert
  ON public.rls_ai_documents;
CREATE POLICY rls_ai_documents_owner_insert
  ON public.rls_ai_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS rls_ai_documents_owner_update
  ON public.rls_ai_documents;
CREATE POLICY rls_ai_documents_owner_update
  ON public.rls_ai_documents
  FOR UPDATE
  TO authenticated
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS rls_ai_documents_owner_delete
  ON public.rls_ai_documents;
CREATE POLICY rls_ai_documents_owner_delete
  ON public.rls_ai_documents
  FOR DELETE
  TO authenticated
  USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS rls_ai_documents_service_role_all
  ON public.rls_ai_documents;
CREATE POLICY rls_ai_documents_service_role_all
  ON public.rls_ai_documents
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS rls_ai_document_acls_select
  ON public.rls_ai_document_acls;
CREATE POLICY rls_ai_document_acls_select
  ON public.rls_ai_document_acls
  FOR SELECT
  TO authenticated
  USING (
    grantee_user_id = auth.uid()
    OR public.is_rls_ai_document_owner(document_id)
  );

DROP POLICY IF EXISTS rls_ai_document_acls_owner_insert
  ON public.rls_ai_document_acls;
CREATE POLICY rls_ai_document_acls_owner_insert
  ON public.rls_ai_document_acls
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_rls_ai_document_owner(document_id)
    AND granted_by_user_id = auth.uid()
  );

DROP POLICY IF EXISTS rls_ai_document_acls_owner_update
  ON public.rls_ai_document_acls;
CREATE POLICY rls_ai_document_acls_owner_update
  ON public.rls_ai_document_acls
  FOR UPDATE
  TO authenticated
  USING (public.is_rls_ai_document_owner(document_id))
  WITH CHECK (public.is_rls_ai_document_owner(document_id));

DROP POLICY IF EXISTS rls_ai_document_acls_owner_delete
  ON public.rls_ai_document_acls;
CREATE POLICY rls_ai_document_acls_owner_delete
  ON public.rls_ai_document_acls
  FOR DELETE
  TO authenticated
  USING (public.is_rls_ai_document_owner(document_id));

DROP POLICY IF EXISTS rls_ai_document_acls_service_role_all
  ON public.rls_ai_document_acls;
CREATE POLICY rls_ai_document_acls_service_role_all
  ON public.rls_ai_document_acls
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.guard_rls_ai_document()
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
      RAISE EXCEPTION 'Authentication required for rls_ai_documents'
        USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.owner_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'owner_user_id must match authenticated caller'
          USING ERRCODE = '42501';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, owner_user_id, created_at cannot be modified'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.acl_version < OLD.acl_version THEN
        RAISE EXCEPTION 'acl_version cannot decrease (% -> %)', OLD.acl_version, NEW.acl_version
          USING ERRCODE = '22000';
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_rls_ai_document
  ON public.rls_ai_documents;
CREATE TRIGGER trg_guard_rls_ai_document
  BEFORE INSERT OR UPDATE
  ON public.rls_ai_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_rls_ai_document();

CREATE OR REPLACE FUNCTION public.guard_rls_ai_document_acl()
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
      RAISE EXCEPTION 'Authentication required for rls_ai_document_acls'
        USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_rls_ai_document_owner(NEW.document_id) THEN
      RAISE EXCEPTION 'Only document owners or service_role may manage document ACLs'
        USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.granted_by_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'granted_by_user_id must match authenticated caller'
          USING ERRCODE = '42501';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.document_id IS DISTINCT FROM OLD.document_id
        OR NEW.grantee_user_id IS DISTINCT FROM OLD.grantee_user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, document_id, grantee_user_id, created_at cannot be modified'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.granted_by_user_id IS DISTINCT FROM OLD.granted_by_user_id
        AND NEW.granted_by_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'granted_by_user_id cannot be spoofed for another user'
          USING ERRCODE = '42501';
      END IF;
      NEW.granted_by_user_id := auth.uid();
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_rls_ai_document_acl
  ON public.rls_ai_document_acls;
CREATE TRIGGER trg_guard_rls_ai_document_acl
  BEFORE INSERT OR UPDATE
  ON public.rls_ai_document_acls
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_rls_ai_document_acl();

CREATE OR REPLACE FUNCTION public.bump_rls_ai_document_acl_version()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc_id uuid;
BEGIN
  v_doc_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.document_id ELSE NEW.document_id END;
  UPDATE public.rls_ai_documents
  SET acl_version = acl_version + 1,
      updated_at = timezone('utc', now())
  WHERE id = v_doc_id;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.bump_rls_ai_document_acl_version() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_bump_rls_ai_document_acl_version
  ON public.rls_ai_document_acls;
CREATE TRIGGER trg_bump_rls_ai_document_acl_version
  AFTER INSERT OR UPDATE OR DELETE
  ON public.rls_ai_document_acls
  FOR EACH ROW
  EXECUTE FUNCTION public.bump_rls_ai_document_acl_version();

-- Strict SECURITY INVOKER RPC enforcing auth.uid() + active ACL filtering
-- BEFORE computing vector cosine or lexical similarity.
CREATE OR REPLACE FUNCTION public.search_rls_authorized_ai_documents(
  p_query text DEFAULT '',
  p_query_embedding double precision[] DEFAULT NULL,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  document_id uuid,
  external_source_key text,
  title text,
  content_excerpt text,
  acl_version integer,
  permission_source text,
  similarity_score double precision,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_caller uuid;
  v_clean_query text;
  v_limit integer;
  v_query_vec vector(768);
BEGIN
  v_caller := auth.uid();
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required for search_rls_authorized_ai_documents'
      USING ERRCODE = '42501';
  END IF;

  v_clean_query := trim(coalesce(p_query, ''));
  v_limit := greatest(1, least(coalesce(p_limit, 10), 50));

  IF p_query_embedding IS NOT NULL AND array_length(p_query_embedding, 1) = 768 THEN
    v_query_vec := format('[%s]', array_to_string(p_query_embedding, ','))::vector(768);
  ELSE
    v_query_vec := NULL;
  END IF;

  RETURN QUERY
  WITH authorized_docs AS (
    SELECT
      d.id,
      d.external_source_key,
      d.title,
      d.content_excerpt,
      d.search_text,
      d.embedding,
      d.search_vector,
      d.acl_version,
      d.updated_at,
      CASE
        WHEN d.owner_user_id = v_caller THEN 'owner'
        ELSE COALESCE(
          (
            SELECT a.permission_level
            FROM public.rls_ai_document_acls a
            WHERE a.document_id = d.id
              AND a.grantee_user_id = v_caller
              AND a.revoked_at IS NULL
            LIMIT 1
          ),
          'viewer'
        )
      END AS permission_source
    FROM public.rls_ai_documents d
    WHERE d.owner_user_id = v_caller
       OR EXISTS (
         SELECT 1
         FROM public.rls_ai_document_acls a
         WHERE a.document_id = d.id
           AND a.grantee_user_id = v_caller
           AND a.revoked_at IS NULL
       )
  ),
  scored AS (
    SELECT
      ad.id AS document_id,
      ad.external_source_key,
      ad.title,
      ad.content_excerpt,
      ad.acl_version,
      ad.permission_source,
      GREATEST(
        CASE
          WHEN v_query_vec IS NOT NULL AND ad.embedding IS NOT NULL
            THEN GREATEST(0.0::double precision, (1.0 - (ad.embedding <=> v_query_vec))::double precision)
          ELSE 0.0::double precision
        END,
        CASE
          WHEN v_clean_query <> '' AND ad.search_vector @@ plainto_tsquery('simple', v_clean_query)
            THEN LEAST(1.0::double precision, ts_rank_cd(ad.search_vector, plainto_tsquery('simple', v_clean_query))::double precision + 0.5)
          WHEN v_clean_query <> '' AND position(lower(v_clean_query) IN lower(ad.title || ' ' || ad.content_excerpt)) > 0
            THEN 0.75::double precision
          WHEN v_clean_query = ''
            THEN 0.50::double precision
          ELSE 0.0::double precision
        END
      ) AS similarity_score,
      ad.updated_at
    FROM authorized_docs ad
  )
  SELECT
    s.document_id,
    s.external_source_key,
    s.title,
    s.content_excerpt,
    s.acl_version,
    s.permission_source,
    s.similarity_score,
    s.updated_at
  FROM scored s
  WHERE v_clean_query = '' OR v_query_vec IS NOT NULL OR s.similarity_score > 0.0
  ORDER BY s.similarity_score DESC, s.updated_at DESC
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.search_rls_authorized_ai_documents(text, double precision[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_rls_authorized_ai_documents(text, double precision[], integer) TO authenticated;

COMMENT ON TABLE public.rls_ai_documents IS
  'External-source documents with pgvector/tsvector index and ACL version synchronized for RLS AI search (#2655).';

COMMENT ON TABLE public.rls_ai_document_acls IS
  'Per-user active/revoked ACL grants enforcing immediate external permission sync (#2655).';

COMMENT ON FUNCTION public.search_rls_authorized_ai_documents(text, double precision[], integer) IS
  'SECURITY INVOKER hybrid vector/lexical search filtering strictly by owner_user_id or unrevoked grantee ACL BEFORE similarity scoring (#2655).';
