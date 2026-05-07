CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS public.kg_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id text NOT NULL,
  source_type text NOT NULL CHECK (
    source_type IN ('issue', 'wbs', 'doc', 'memory', 'notebooklm')
  ),
  source_url text NOT NULL DEFAULT '',
  title text,
  content text NOT NULL,
  excerpt text,
  content_hash text NOT NULL,
  embedding vector(768),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(excerpt, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(content, '')), 'C')
  ) STORED,
  CONSTRAINT kg_embeddings_source_unique UNIQUE (source_type, source_id)
);

COMMENT ON COLUMN public.kg_embeddings.embedding IS
  'Phase 1 uses 768-d Gemini embeddings to match memory_index and memory-search-hub vector search.';

CREATE INDEX IF NOT EXISTS kg_embeddings_source_type_idx
  ON public.kg_embeddings (source_type, last_synced_at DESC);

CREATE INDEX IF NOT EXISTS kg_embeddings_content_hash_idx
  ON public.kg_embeddings (content_hash);

CREATE INDEX IF NOT EXISTS kg_embeddings_search_vector_idx
  ON public.kg_embeddings USING gin (search_vector);

CREATE INDEX IF NOT EXISTS kg_embeddings_embedding_idx
  ON public.kg_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100)
  WHERE embedding IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.kg_query_logs (
  trace_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  client_key text NOT NULL DEFAULT 'anonymous',
  query text NOT NULL,
  sources text[] NOT NULL DEFAULT ARRAY['issue','wbs','doc','memory','notebooklm'],
  top_k integer NOT NULL DEFAULT 8 CHECK (top_k BETWEEN 1 AND 20),
  answer_status text NOT NULL CHECK (
    answer_status IN ('ok', 'no_results', 'stale_index', 'llm_failure')
  ),
  citation_count integer NOT NULL DEFAULT 0 CHECK (citation_count >= 0),
  latency_ms integer NOT NULL DEFAULT 0 CHECK (latency_ms >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS kg_query_logs_user_time_idx
  ON public.kg_query_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS kg_query_logs_client_time_idx
  ON public.kg_query_logs (client_key, created_at DESC);

CREATE INDEX IF NOT EXISTS kg_query_logs_status_time_idx
  ON public.kg_query_logs (answer_status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.kg_indexer_failures (
  id bigserial PRIMARY KEY,
  source_type text NOT NULL CHECK (
    source_type IN ('issue', 'wbs', 'doc', 'memory', 'notebooklm')
  ),
  source_id text NOT NULL DEFAULT '',
  source_url text NOT NULL DEFAULT '',
  error_message text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS kg_indexer_failures_open_idx
  ON public.kg_indexer_failures (source_type, created_at DESC)
  WHERE resolved_at IS NULL;

ALTER TABLE public.kg_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_query_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kg_indexer_failures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kg_embeddings_service_all" ON public.kg_embeddings
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "kg_query_logs_service_all" ON public.kg_query_logs
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "kg_query_logs_owner_select" ON public.kg_query_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "kg_indexer_failures_service_all" ON public.kg_indexer_failures
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION public.match_kg_embeddings(
  query_embedding vector(768),
  match_count integer DEFAULT 8,
  match_threshold double precision DEFAULT 0.5,
  source_filter text[] DEFAULT NULL
)
RETURNS TABLE (
  source_id text,
  source_type text,
  source_url text,
  title text,
  content text,
  excerpt text,
  metadata jsonb,
  last_synced_at timestamptz,
  score double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    e.source_id,
    e.source_type,
    e.source_url,
    e.title,
    e.content,
    e.excerpt,
    e.metadata,
    e.last_synced_at,
    1 - (e.embedding <=> query_embedding) AS score
  FROM public.kg_embeddings e
  WHERE e.embedding IS NOT NULL
    AND (
      source_filter IS NULL
      OR cardinality(source_filter) = 0
      OR e.source_type = ANY(source_filter)
    )
    AND 1 - (e.embedding <=> query_embedding) >= match_threshold
  ORDER BY e.embedding <=> query_embedding
  LIMIT LEAST(GREATEST(match_count, 1), 50);
$$;

GRANT EXECUTE ON FUNCTION public.match_kg_embeddings(vector, integer, double precision, text[])
  TO service_role;
