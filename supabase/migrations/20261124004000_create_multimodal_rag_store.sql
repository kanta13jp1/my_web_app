-- Batch 98 (#2687): Multimodal RAG (Gemini Embedding 2) pgvector + Storage integration.
-- Creates private Storage bucket `multimodal-rag-media`, parent `multimodal_rag_items`,
-- child `multimodal_rag_chunks`, strict owner-scoped RLS/Storage policies, and
-- SECURITY INVOKER hybrid vector/lexical search RPC.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.multimodal_rag_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  source_key text NOT NULL CHECK (char_length(btrim(source_key)) BETWEEN 1 AND 200),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 240),
  modality text NOT NULL CHECK (modality IN ('text', 'image', 'audio', 'video', 'pdf', 'mixed')),
  mime_type text NOT NULL DEFAULT 'text/plain' CHECK (
    mime_type IN (
      'text/plain',
      'text/markdown',
      'image/png',
      'image/jpeg',
      'audio/mpeg',
      'audio/wav',
      'video/mp4',
      'application/pdf',
      'multipart/mixed'
    )
  ),
  storage_object_path text CHECK (
    storage_object_path IS NULL OR (
      char_length(btrim(storage_object_path)) BETWEEN 3 AND 512
      AND storage_object_path LIKE owner_user_id::text || '/%'
    )
  ),
  content_text text NOT NULL DEFAULT '',
  media_sha256 text NOT NULL DEFAULT '' CHECK (char_length(media_sha256) <= 64),
  byte_size bigint NOT NULL DEFAULT 0 CHECK (byte_size >= 0 AND byte_size <= 10485760),
  duration_sec integer CHECK (duration_sec IS NULL OR (duration_sec >= 0 AND duration_sec <= 86400)),
  page_count integer CHECK (page_count IS NULL OR (page_count >= 1 AND page_count <= 2000)),
  chunk_count integer NOT NULL DEFAULT 1 CHECK (chunk_count BETWEEN 1 AND 256),
  embedding_model text NOT NULL DEFAULT 'gemini-embedding-2' CHECK (
    embedding_model IN ('gemini-embedding-2', 'deterministic-fallback')
  ),
  embedding_mode text NOT NULL DEFAULT 'live' CHECK (
    embedding_mode IN ('live', 'offline_fallback')
  ),
  embedding vector(768),
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(content_text, '')), 'B')
  ) STORED,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_multimodal_rag_items_owner_source UNIQUE (owner_user_id, source_key)
);

CREATE TABLE IF NOT EXISTS public.multimodal_rag_chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.multimodal_rag_items(id) ON DELETE CASCADE,
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  chunk_index integer NOT NULL CHECK (chunk_index >= 0),
  modality text NOT NULL CHECK (modality IN ('text', 'image', 'audio', 'video', 'pdf')),
  text_excerpt text NOT NULL DEFAULT '',
  start_offset_sec integer CHECK (start_offset_sec IS NULL OR start_offset_sec >= 0),
  end_offset_sec integer CHECK (end_offset_sec IS NULL OR end_offset_sec >= 0),
  page_start integer CHECK (page_start IS NULL OR page_start >= 1),
  page_end integer CHECK (page_end IS NULL OR page_end >= 1),
  embedding vector(768),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_multimodal_rag_chunks_item_idx UNIQUE (item_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_items_owner_modality_updated
  ON public.multimodal_rag_items (owner_user_id, modality, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_items_search_vector
  ON public.multimodal_rag_items USING gin (search_vector);

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_items_embedding
  ON public.multimodal_rag_items USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_chunks_item_order
  ON public.multimodal_rag_chunks (item_id, chunk_index ASC);

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_chunks_owner
  ON public.multimodal_rag_chunks (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_multimodal_rag_chunks_embedding
  ON public.multimodal_rag_chunks USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;

ALTER TABLE public.multimodal_rag_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.multimodal_rag_chunks ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.multimodal_rag_items FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.multimodal_rag_items TO authenticated;
GRANT ALL ON TABLE public.multimodal_rag_items TO service_role;

REVOKE ALL ON TABLE public.multimodal_rag_chunks FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.multimodal_rag_chunks TO authenticated;
GRANT ALL ON TABLE public.multimodal_rag_chunks TO service_role;

DROP POLICY IF EXISTS multimodal_rag_items_select_own ON public.multimodal_rag_items;
CREATE POLICY multimodal_rag_items_select_own
  ON public.multimodal_rag_items
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_items_insert_own ON public.multimodal_rag_items;
CREATE POLICY multimodal_rag_items_insert_own
  ON public.multimodal_rag_items
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_items_update_own ON public.multimodal_rag_items;
CREATE POLICY multimodal_rag_items_update_own
  ON public.multimodal_rag_items
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id)
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_items_delete_own ON public.multimodal_rag_items;
CREATE POLICY multimodal_rag_items_delete_own
  ON public.multimodal_rag_items
  FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_chunks_select_own ON public.multimodal_rag_chunks;
CREATE POLICY multimodal_rag_chunks_select_own
  ON public.multimodal_rag_chunks
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_chunks_insert_own ON public.multimodal_rag_chunks;
CREATE POLICY multimodal_rag_chunks_insert_own
  ON public.multimodal_rag_chunks
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_chunks_update_own ON public.multimodal_rag_chunks;
CREATE POLICY multimodal_rag_chunks_update_own
  ON public.multimodal_rag_chunks
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id)
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS multimodal_rag_chunks_delete_own ON public.multimodal_rag_chunks;
CREATE POLICY multimodal_rag_chunks_delete_own
  ON public.multimodal_rag_chunks
  FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

CREATE OR REPLACE FUNCTION public.guard_multimodal_rag_item()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $guard$
DECLARE
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
  v_is_service boolean;
BEGIN
  IF v_claims_raw IS NOT NULL AND length(trim(v_claims_raw)) > 0 THEN
    BEGIN
      v_claims := v_claims_raw::jsonb;
    EXCEPTION
      WHEN OTHERS THEN
        v_claims := '{}'::jsonb;
    END;
  END IF;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for multimodal_rag_items'
        USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'INSERT' THEN
      NEW.owner_user_id := auth.uid();
    ELSIF NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
       OR NEW.id IS DISTINCT FROM OLD.id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Immutable columns id, owner_user_id, created_at cannot be modified'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_at := coalesce(NEW.created_at, timezone('utc', now()));
  END IF;
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$guard$;

REVOKE ALL ON FUNCTION public.guard_multimodal_rag_item() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_multimodal_rag_item ON public.multimodal_rag_items;
CREATE TRIGGER trg_guard_multimodal_rag_item
  BEFORE INSERT OR UPDATE ON public.multimodal_rag_items
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_multimodal_rag_item();

CREATE OR REPLACE FUNCTION public.guard_multimodal_rag_chunk()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $chunk_guard$
DECLARE
  v_parent_owner uuid;
BEGIN
  SELECT i.owner_user_id
  INTO v_parent_owner
  FROM public.multimodal_rag_items i
  WHERE i.id = NEW.item_id;

  IF v_parent_owner IS NULL THEN
    RAISE EXCEPTION 'Referenced multimodal_rag_items row does not exist'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.owner_user_id IS DISTINCT FROM v_parent_owner THEN
    RAISE EXCEPTION 'Chunk owner_user_id must match parent item owner_user_id'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.id IS DISTINCT FROM OLD.id
    OR NEW.item_id IS DISTINCT FROM OLD.item_id
    OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
    OR NEW.created_at IS DISTINCT FROM OLD.created_at
  ) THEN
    RAISE EXCEPTION 'Immutable chunk columns cannot be modified'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$chunk_guard$;

REVOKE ALL ON FUNCTION public.guard_multimodal_rag_chunk() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_multimodal_rag_chunk ON public.multimodal_rag_chunks;
CREATE TRIGGER trg_guard_multimodal_rag_chunk
  BEFORE INSERT OR UPDATE ON public.multimodal_rag_chunks
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_multimodal_rag_chunk();

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'multimodal-rag-media',
  'multimodal-rag-media',
  false,
  10485760,
  array[
    'image/png',
    'image/jpeg',
    'application/pdf',
    'audio/mpeg',
    'audio/wav',
    'video/mp4'
  ]::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

DROP POLICY IF EXISTS multimodal_rag_media_select_own ON storage.objects;
CREATE POLICY multimodal_rag_media_select_own
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'multimodal-rag-media'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS multimodal_rag_media_insert_own ON storage.objects;
CREATE POLICY multimodal_rag_media_insert_own
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'multimodal-rag-media'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS multimodal_rag_media_delete_own ON storage.objects;
CREATE POLICY multimodal_rag_media_delete_own
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'multimodal-rag-media'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

CREATE OR REPLACE FUNCTION public.search_multimodal_rag_items(
  p_query text DEFAULT '',
  p_query_embedding double precision[] DEFAULT NULL,
  p_modalities text[] DEFAULT NULL,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  item_id uuid,
  source_key text,
  title text,
  modality text,
  mime_type text,
  storage_object_path text,
  matched_excerpt text,
  chunk_count integer,
  embedding_model text,
  embedding_mode text,
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
  v_has_modality_filter boolean;
BEGIN
  v_caller := auth.uid();
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required for search_multimodal_rag_items'
      USING ERRCODE = '42501';
  END IF;

  v_clean_query := trim(coalesce(p_query, ''));
  v_limit := greatest(1, least(coalesce(p_limit, 10), 50));
  v_has_modality_filter := p_modalities IS NOT NULL AND coalesce(array_length(p_modalities, 1), 0) > 0;

  IF p_query_embedding IS NOT NULL AND array_length(p_query_embedding, 1) = 768 THEN
    v_query_vec := format('[%s]', array_to_string(p_query_embedding, ','))::vector(768);
  ELSE
    v_query_vec := NULL;
  END IF;

  RETURN QUERY
  WITH owner_items AS (
    SELECT
      i.id,
      i.source_key,
      i.title,
      i.modality,
      i.mime_type,
      i.storage_object_path,
      i.content_text,
      i.chunk_count,
      i.embedding_model,
      i.embedding_mode,
      i.embedding,
      i.search_vector,
      i.updated_at
    FROM public.multimodal_rag_items i
    WHERE i.owner_user_id = v_caller
      AND (NOT v_has_modality_filter OR i.modality = ANY(p_modalities))
  ),
  scored AS (
    SELECT
      oi.id AS item_id,
      oi.source_key,
      oi.title,
      oi.modality,
      oi.mime_type,
      oi.storage_object_path,
      coalesce(
        (
          SELECT c.text_excerpt
          FROM public.multimodal_rag_chunks c
          WHERE c.item_id = oi.id
            AND c.owner_user_id = v_caller
          ORDER BY
            CASE
              WHEN v_query_vec IS NOT NULL AND c.embedding IS NOT NULL
                THEN (c.embedding <=> v_query_vec)
              ELSE 1.0
            END ASC,
            c.chunk_index ASC
          LIMIT 1
        ),
        left(oi.content_text, 240)
      ) AS matched_excerpt,
      oi.chunk_count,
      oi.embedding_model,
      oi.embedding_mode,
      GREATEST(
        CASE
          WHEN v_query_vec IS NOT NULL AND oi.embedding IS NOT NULL
            THEN GREATEST(0.0::double precision, (1.0 - (oi.embedding <=> v_query_vec))::double precision)
          ELSE 0.0::double precision
        END,
        coalesce(
          (
            SELECT max(
              CASE
                WHEN v_query_vec IS NOT NULL AND c.embedding IS NOT NULL
                  THEN GREATEST(0.0::double precision, (1.0 - (c.embedding <=> v_query_vec))::double precision)
                ELSE 0.0::double precision
              END
            )
            FROM public.multimodal_rag_chunks c
            WHERE c.item_id = oi.id
              AND c.owner_user_id = v_caller
          ),
          0.0::double precision
        ),
        CASE
          WHEN v_clean_query <> '' AND oi.search_vector @@ plainto_tsquery('simple', v_clean_query)
            THEN LEAST(1.0::double precision, ts_rank_cd(oi.search_vector, plainto_tsquery('simple', v_clean_query))::double precision + 0.5)
          WHEN v_clean_query <> '' AND position(lower(v_clean_query) IN lower(oi.title || ' ' || oi.content_text)) > 0
            THEN 0.72::double precision
          WHEN v_clean_query = ''
            THEN 0.50::double precision
          ELSE 0.0::double precision
        END
      ) AS similarity_score,
      oi.updated_at
    FROM owner_items oi
  )
  SELECT
    s.item_id,
    s.source_key,
    s.title,
    s.modality,
    s.mime_type,
    s.storage_object_path,
    s.matched_excerpt,
    s.chunk_count,
    s.embedding_model,
    s.embedding_mode,
    s.similarity_score,
    s.updated_at
  FROM scored s
  WHERE v_clean_query = '' OR v_query_vec IS NOT NULL OR s.similarity_score > 0.0
  ORDER BY s.similarity_score DESC, s.updated_at DESC
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.search_multimodal_rag_items(text, double precision[], text[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_multimodal_rag_items(text, double precision[], text[], integer) TO authenticated;

COMMENT ON TABLE public.multimodal_rag_items IS
  'Owner-scoped multimodal RAG items with pgvector 768-d embeddings and private Storage object binding (#2687).';

COMMENT ON TABLE public.multimodal_rag_chunks IS
  'Owner-scoped multimodal chunks (text windows, video/audio time spans, PDF page windows) (#2687).';

COMMENT ON FUNCTION public.search_multimodal_rag_items(text, double precision[], text[], integer) IS
  'SECURITY INVOKER multimodal hybrid vector/lexical search filtering strictly by owner_user_id BEFORE similarity ranking (#2687).';
