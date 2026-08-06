-- 自分API v1: Notion Developer Platform 対抗 (2026-07-12 WEB版)
-- ユーザー単位の API キー発行 + ユーザー自作 Agent ツール (Worker) 登録基盤。
-- 既存 MCP レーン (mcp_oauth_clients = client 単位・user_id なし) と異なり、
-- 本レーンは auth.users に紐づくユーザースコープの外部 API アクセスを提供する。
-- セキュリティ設計: docs/MCP_AUTH_SECURITY_PRINCIPLES.md + docs/AI_DEV_PRINCIPLES.md 準拠
-- (sha256 ハッシュのみ保存 / deny-by-default / audit log / rate limit / kill switch)

-- ── 1. user_api_keys: ユーザー発行 API キー ────────────────────────────────
-- 平文キー (jibun_sk_...) は発行レスポンス時のみ返却し、以降は sha256 のみ保持する。
-- RLS は service_role 限定 (mcp_oauth_clients と同様、key_hash の総当り攻撃面を排除)。
-- キーの参照・失効は tools-hub Edge Function の jibunapi.* action (JWT 認証) 経由のみ。
CREATE TABLE IF NOT EXISTS public.user_api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  key_prefix text NOT NULL,
  key_hash text NOT NULL,
  scopes jsonb NOT NULL DEFAULT '[]'::jsonb,
  revoked boolean NOT NULL DEFAULT false,
  revoked_at timestamptz,
  expires_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_api_keys_name_not_blank CHECK (length(btrim(name)) > 0),
  CONSTRAINT user_api_keys_name_max_length CHECK (length(name) <= 100),
  CONSTRAINT user_api_keys_prefix_format CHECK (key_prefix LIKE 'jibun_sk_%')
);

CREATE UNIQUE INDEX IF NOT EXISTS user_api_keys_key_hash_uidx
  ON public.user_api_keys (key_hash);
CREATE INDEX IF NOT EXISTS user_api_keys_user_created_idx
  ON public.user_api_keys (user_id, created_at DESC);

ALTER TABLE public.user_api_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_api_keys_service_role_all ON public.user_api_keys;
CREATE POLICY user_api_keys_service_role_all ON public.user_api_keys
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP TRIGGER IF EXISTS update_user_api_keys_updated_at ON public.user_api_keys;
CREATE TRIGGER update_user_api_keys_updated_at
  BEFORE UPDATE ON public.user_api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE public.user_api_keys IS
  '自分API ユーザー発行キー。sha256(key) のみ保存・平文は発行時1回のみ返却。RLS service_role 限定 (EF 経由アクセスのみ)。';
COMMENT ON COLUMN public.user_api_keys.key_hash IS
  'sha256 hex digest。平文キーは保持しない (docs/MCP_AUTH_SECURITY_PRINCIPLES.md #1 準拠)。';
COMMENT ON COLUMN public.user_api_keys.scopes IS
  '許可スコープ配列 (notes.read / notes.write / tasks.read / achievements.read / workers.invoke)。deny-by-default。';

-- ── 2. user_agent_workers: ユーザー自作 Agent ツール (Worker) 登録 ──────────
-- Notion Developer Platform の Worker 対抗。ユーザーが外部 https エンドポイントを
-- 登録し、api.workers.invoke で呼び出す。呼び出し時は signing_secret による
-- HMAC-SHA256 署名 (X-Jibun-Signature) を付与し、受け側が正当性を検証できる。
-- signing_secret は登録レスポンス時のみ返却し、RLS service_role 限定で保管する。
CREATE TABLE IF NOT EXISTS public.user_agent_workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  slug text NOT NULL,
  description text NOT NULL DEFAULT '',
  endpoint_url text NOT NULL,
  signing_secret text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  timeout_ms integer NOT NULL DEFAULT 10000,
  invocation_count bigint NOT NULL DEFAULT 0,
  last_invoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_agent_workers_name_not_blank CHECK (length(btrim(name)) > 0),
  CONSTRAINT user_agent_workers_name_max_length CHECK (length(name) <= 100),
  CONSTRAINT user_agent_workers_slug_format CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,63}$'),
  CONSTRAINT user_agent_workers_endpoint_https CHECK (endpoint_url LIKE 'https://%'),
  CONSTRAINT user_agent_workers_timeout_range CHECK (timeout_ms BETWEEN 1000 AND 15000)
);

CREATE UNIQUE INDEX IF NOT EXISTS user_agent_workers_user_slug_uidx
  ON public.user_agent_workers (user_id, slug);
CREATE INDEX IF NOT EXISTS user_agent_workers_user_created_idx
  ON public.user_agent_workers (user_id, created_at DESC);

ALTER TABLE public.user_agent_workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_agent_workers_service_role_all ON public.user_agent_workers;
CREATE POLICY user_agent_workers_service_role_all ON public.user_agent_workers
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP TRIGGER IF EXISTS update_user_agent_workers_updated_at ON public.user_agent_workers;
CREATE TRIGGER update_user_agent_workers_updated_at
  BEFORE UPDATE ON public.user_agent_workers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE public.user_agent_workers IS
  '自分API ユーザー自作 Agent ツール (Worker)。https 限定 + SSRF ガードは EF 側で二重検証。signing_secret は登録時1回のみ返却。';
COMMENT ON COLUMN public.user_agent_workers.signing_secret IS
  'HMAC-SHA256 署名キー (X-Jibun-Signature 付与用)。service_role RLS で保護。';

-- ── 3. user_api_audit_log: 自分API 監査ログ + rate limit 窓 ─────────────────
-- 全 api.* 呼び出しと鍵/Worker 管理イベントを記録 (AI_DEV 原則3 観測性 + 原則7 品質ゲート)。
-- (api_key_id, created_at) index が per-key rate limit のスライディングウィンドウ照会を支える。
CREATE TABLE IF NOT EXISTS public.user_api_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  api_key_id uuid REFERENCES public.user_api_keys(id) ON DELETE SET NULL,
  worker_id uuid,
  action text NOT NULL,
  status smallint NOT NULL,
  request_ip inet,
  duration_ms integer,
  trace_id text,
  request_preview text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_api_audit_log_preview_max CHECK (
    request_preview IS NULL OR length(request_preview) <= 200
  )
);

CREATE INDEX IF NOT EXISTS user_api_audit_log_key_created_idx
  ON public.user_api_audit_log (api_key_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_api_audit_log_user_created_idx
  ON public.user_api_audit_log (user_id, created_at DESC);

ALTER TABLE public.user_api_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_api_audit_log_service_role_all ON public.user_api_audit_log;
CREATE POLICY user_api_audit_log_service_role_all ON public.user_api_audit_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

COMMENT ON TABLE public.user_api_audit_log IS
  '自分API 監査ログ (90日保持)。rate limit スライディングウィンドウ照会にも使用。';

-- 90日超のログを削除する保守関数 (mcp_audit_log の purge_mcp_audit_log と同型)
CREATE OR REPLACE FUNCTION public.purge_user_api_audit_log()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM public.user_api_audit_log
  WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_user_api_audit_log() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_user_api_audit_log() TO service_role;
