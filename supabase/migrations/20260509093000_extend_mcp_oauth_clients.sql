-- Issue #1577 Phase A: harden MCP OAuth client registry metadata.
--
-- These columns prepare DCR clients for Terraform ownership, CIMD migration,
-- reputation checks, and 90-day secret rotation without changing the existing
-- auth flow.

ALTER TABLE public.mcp_oauth_clients
  ADD COLUMN IF NOT EXISTS metadata_document_url text,
  ADD COLUMN IF NOT EXISTS managed_by text NOT NULL DEFAULT 'terraform'
    CHECK (managed_by IN ('terraform', 'manual_admin')),
  ADD COLUMN IF NOT EXISTS reputation_score smallint NOT NULL DEFAULT 50
    CHECK (reputation_score BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS rotation_due_at timestamptz;

CREATE INDEX IF NOT EXISTS mcp_oauth_clients_rotation_due_idx
  ON public.mcp_oauth_clients (rotation_due_at)
  WHERE rotation_due_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS mcp_oauth_clients_metadata_document_idx
  ON public.mcp_oauth_clients (metadata_document_url)
  WHERE metadata_document_url IS NOT NULL;

COMMENT ON COLUMN public.mcp_oauth_clients.metadata_document_url IS
  'Optional CIMD metadata document URL. NULL means Phase 1 DCR client.';
COMMENT ON COLUMN public.mcp_oauth_clients.managed_by IS
  'OAuth client source of truth. Expected value is terraform; manual_admin marks break-glass rows.';
COMMENT ON COLUMN public.mcp_oauth_clients.reputation_score IS
  '0-100 client reputation score used by future DCR abuse and anomaly gates.';
COMMENT ON COLUMN public.mcp_oauth_clients.rotation_due_at IS
  'Timestamp when client secret rotation is due.';
