-- Asynchronous long-running background jobs tracking table (#2731)
-- Supports HTTP 202 enqueue -> Realtime / polling status tracking -> result retrieval.

CREATE TABLE IF NOT EXISTS public.async_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  job_type text NOT NULL,
  title text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
  progress_percent integer NOT NULL DEFAULT 0
    CHECK (progress_percent >= 0 AND progress_percent <= 100),
  request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  result_payload jsonb,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS async_jobs_user_created_idx
  ON public.async_jobs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS async_jobs_user_status_idx
  ON public.async_jobs (user_id, status);

ALTER TABLE public.async_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS async_jobs_owner_select ON public.async_jobs;
CREATE POLICY async_jobs_owner_select ON public.async_jobs
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS async_jobs_owner_insert ON public.async_jobs;
CREATE POLICY async_jobs_owner_insert ON public.async_jobs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS async_jobs_owner_update ON public.async_jobs;
CREATE POLICY async_jobs_owner_update ON public.async_jobs
  FOR UPDATE
  USING (auth.uid() = user_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS async_jobs_service_delete ON public.async_jobs;
CREATE POLICY async_jobs_service_delete ON public.async_jobs
  FOR DELETE
  USING (auth.role() = 'service_role');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'async_jobs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.async_jobs;
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR duplicate_object THEN
    NULL;
END;
$$;
