-- MCP Audit Log — tool 呼び出しの全件記録テーブル
--
-- docs/MCP_AUTH_SECURITY_PRINCIPLES.md 原則 #7 (Audit Log + Anomaly Detection) の
-- 実装基盤。全 MCP tool 呼び出しを 1 行 INSERT し、daily aggregator (GHA cron /
-- 後続実装) で client_id × 5min 異常検出 → Slack alert + suspend する。
--
-- arXiv 論文の **Cross-Server Propagation** + **Cross-Session Persistence** 攻撃
-- 検出のため、client_id 単位だけでなく **tool 呼び出し連鎖** を可視化できる
-- インデックス設計 (client_id × invoked_at DESC + tool_name) を採用。

CREATE TABLE IF NOT EXISTS public.mcp_audit_log (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id         text        NOT NULL,
  tool_name         text        NOT NULL,
  -- request 引数 (delimiter 化済) — null 許容 (sampling 等の引数なし呼び出し)
  request_args      jsonb,
  -- HTTP response status (200 / 401 / 403 / 500 等)
  response_status   smallint    NOT NULL,
  -- 異常検出用 IP (x-forwarded-for / cf-connecting-ip / GDPR 配慮で 30 日後 anonymize 推奨)
  request_ip        inet,
  -- response 先頭 200 char (prompt injection の検出証跡 / 機微データ含めない設計)
  response_preview  text,
  invoked_at        timestamptz NOT NULL DEFAULT now()
);

-- 主クエリパターン: 「直近 5min の client_id 単位の呼び出し数」が p99×3 超えで alert
CREATE INDEX IF NOT EXISTS mcp_audit_log_client_invoked_idx
  ON public.mcp_audit_log (client_id, invoked_at DESC);

-- 副クエリパターン: 「Cross-Server Propagation 検出」のため tool_name 単位の頻度監視
CREATE INDEX IF NOT EXISTS mcp_audit_log_tool_invoked_idx
  ON public.mcp_audit_log (tool_name, invoked_at DESC);

-- 副クエリパターン: 4xx/5xx 連発検出 (失敗で大量試行 = 攻撃 signature)
CREATE INDEX IF NOT EXISTS mcp_audit_log_failure_idx
  ON public.mcp_audit_log (response_status, invoked_at DESC)
  WHERE response_status >= 400;

ALTER TABLE public.mcp_audit_log ENABLE ROW LEVEL SECURITY;

-- service_role のみ INSERT/SELECT (mcp_auth_guard.logMcpInvocation 経由)
CREATE POLICY "service_role write mcp_audit_log"
  ON public.mcp_audit_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- anon read 不可 (request_args に機微データが含まれる前提)

COMMENT ON TABLE public.mcp_audit_log IS
  'MCP tool invocation audit trail — required for arXiv attack vector B/C detection';
COMMENT ON COLUMN public.mcp_audit_log.response_preview IS
  '応答先頭 200 char (prompt injection 試行の証跡 / 機微データを含めない設計)';
COMMENT ON COLUMN public.mcp_audit_log.request_ip IS
  'x-forwarded-for の左端 IP / GDPR 配慮で 30 日後 anonymize 推奨';
