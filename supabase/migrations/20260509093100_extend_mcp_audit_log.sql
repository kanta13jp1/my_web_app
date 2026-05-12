-- Issue #1577 Phase A: add anomaly and origin metadata to MCP audit logs.

ALTER TABLE public.mcp_audit_log
  ADD COLUMN IF NOT EXISTS anomaly_score numeric DEFAULT 0
    CHECK (anomaly_score BETWEEN 0 AND 1.0),
  ADD COLUMN IF NOT EXISTS cross_server_trace text,
  ADD COLUMN IF NOT EXISTS origin_tag text
    CHECK (origin_tag IN ('tool', 'user') OR origin_tag IS NULL);

CREATE INDEX IF NOT EXISTS mcp_audit_anomaly_recent
  ON public.mcp_audit_log (invoked_at DESC, anomaly_score)
  WHERE anomaly_score > 0.7;

CREATE INDEX IF NOT EXISTS mcp_audit_cross_server
  ON public.mcp_audit_log (cross_server_trace, invoked_at DESC)
  WHERE cross_server_trace IS NOT NULL;

CREATE OR REPLACE FUNCTION public.purge_mcp_audit_log() RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.mcp_audit_log
  WHERE invoked_at < (now() - INTERVAL '90 days');
$$;

COMMENT ON COLUMN public.mcp_audit_log.anomaly_score IS
  '0-1 anomaly score populated by the future MCP audit anomaly cron.';
COMMENT ON COLUMN public.mcp_audit_log.cross_server_trace IS
  'Correlation key for cross-server propagation detection.';
COMMENT ON COLUMN public.mcp_audit_log.origin_tag IS
  'Future sampling origin tag. NULL means sampling is not enabled.';
COMMENT ON FUNCTION public.purge_mcp_audit_log() IS
  'Deletes MCP audit log rows older than 90 days.';
