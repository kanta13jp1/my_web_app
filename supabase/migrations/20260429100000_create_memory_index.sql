-- SECOND_BRAIN #7: memory_index for memory-search-hub.
-- Cloud EF cannot read local claude-mem SQLite directly, so memory files sync here.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS memory_index (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  file_path text NOT NULL UNIQUE,
  title text,
  content text NOT NULL DEFAULT '',
  snippet text,
  content_hash text NOT NULL,
  source text NOT NULL DEFAULT 'memory',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  embedding vector(768),
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(file_path, '') || ' ' || coalesce(content, '')
    )
  ) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE memory_index ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS memory_index_service_role ON memory_index;
CREATE POLICY memory_index_service_role ON memory_index
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE INDEX IF NOT EXISTS memory_index_search_vector_idx
  ON memory_index USING gin (search_vector);

CREATE INDEX IF NOT EXISTS memory_index_source_updated_idx
  ON memory_index (source, updated_at DESC);

CREATE INDEX IF NOT EXISTS memory_index_embedding_idx
  ON memory_index USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

DROP TRIGGER IF EXISTS update_memory_index_updated_at ON memory_index;
CREATE TRIGGER update_memory_index_updated_at
  BEFORE UPDATE ON memory_index
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION match_memory_index(
  query_embedding vector(768),
  match_count int DEFAULT 20,
  match_threshold double precision DEFAULT 0.05
)
RETURNS TABLE (
  file_path text,
  title text,
  content text,
  snippet text,
  metadata jsonb,
  score double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    mi.file_path,
    mi.title,
    mi.content,
    mi.snippet,
    mi.metadata,
    1 - (mi.embedding <=> query_embedding) AS score
  FROM memory_index mi
  WHERE mi.embedding IS NOT NULL
    AND 1 - (mi.embedding <=> query_embedding) >= match_threshold
  ORDER BY mi.embedding <=> query_embedding
  LIMIT LEAST(GREATEST(match_count, 1), 50);
$$;

COMMENT ON TABLE memory_index IS 'SECOND_BRAIN #7 hybrid search index. Synced from memory/*.md and future claude-mem exports.';
COMMENT ON FUNCTION match_memory_index(vector, int, double precision) IS 'pgvector cosine search helper for memory-search-hub.';

REVOKE ALL ON FUNCTION public.match_memory_index(vector, int, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_memory_index(vector, int, double precision) TO service_role;
