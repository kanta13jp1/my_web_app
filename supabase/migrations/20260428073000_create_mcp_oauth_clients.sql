-- MCP OAuth Clients — Dynamic Client Registration (RFC 7591) 用テーブル
--
-- docs/MCP_AUTH_SECURITY_PRINCIPLES.md 原則 #1 (DCR) の実装基盤。
-- mcp-auth-register EF (後続実装) が POST /register を受けてここに INSERT する。
-- mcp_auth_guard.ts validateBearer() は token の client_id でこの表を引いて
-- suspended=true なら拒否する。
--
-- ソース: NotebookLM Notebook 1b808a60-85d6-49f7-ab80-0e90a43cf1d8
-- "Streamlining MCP Authentication with WorkOS AuthKit" + RFC 7591 + Mercari DCR 事例

CREATE TABLE IF NOT EXISTS public.mcp_oauth_clients (
  -- DCR で発行される client_id (UUID v4 / public で OK)
  client_id           text        PRIMARY KEY,
  -- client_secret は sha256 ハッシュで保存 (平文 NG)
  -- DCR レスポンス時のみ平文を返却し、その後はハッシュのみ保持
  client_secret_hash  text        NOT NULL,
  -- DCR で登録されるメタデータ (RFC 7591 fields)
  client_name         text,
  redirect_uris       jsonb       NOT NULL DEFAULT '[]'::jsonb,
  grant_types         jsonb       NOT NULL DEFAULT '["authorization_code"]'::jsonb,
  scopes              jsonb       NOT NULL DEFAULT '[]'::jsonb,
  -- 登録時のクライアント IP (rate limit / abuse 検出用 / GDPR 配慮で 90 日後に anonymize 推奨)
  created_by_ip       inet,
  -- 異常検出 / 手動 suspend 用フラグ (mcp_audit_log 連携で anomaly に達したら true)
  suspended           boolean     NOT NULL DEFAULT false,
  suspended_reason    text,
  suspended_at        timestamptz,
  -- 監査用メタ
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_used_at        timestamptz
);

CREATE INDEX IF NOT EXISTS mcp_oauth_clients_suspended_idx
  ON public.mcp_oauth_clients (suspended)
  WHERE suspended = true;

CREATE INDEX IF NOT EXISTS mcp_oauth_clients_created_at_idx
  ON public.mcp_oauth_clients (created_at DESC);

ALTER TABLE public.mcp_oauth_clients ENABLE ROW LEVEL SECURITY;

-- service_role のみ書込み (DCR EF + mcp_auth_guard 経由)
CREATE POLICY "service_role write mcp_oauth_clients"
  ON public.mcp_oauth_clients
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- anon は読込みすら不可 (client_secret_hash の総当り攻撃面を排除)
-- ※ DCR EF が service_role で個別 SELECT する設計

COMMENT ON TABLE public.mcp_oauth_clients IS
  'MCP server Dynamic Client Registration (RFC 7591) — managed by mcp-auth-register EF';
COMMENT ON COLUMN public.mcp_oauth_clients.client_secret_hash IS
  'sha256(client_secret). 平文は DCR レスポンス時のみ返却・以降保持しない';
COMMENT ON COLUMN public.mcp_oauth_clients.suspended IS
  'true なら mcp_auth_guard.validateBearer() が即 401 拒否';
