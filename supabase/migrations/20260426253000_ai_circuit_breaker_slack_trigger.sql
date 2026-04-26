-- Issue #696 S3: ai_circuit_breaker → Slack post trigger
-- Win版#132 part 36 / 2026-04-26
--
-- ai_circuit_breaker.state が closed → open に遷移したとき、
-- core-hub:slack.notify (channel='quota') 経由で Slack へ通知する。
--
-- 前提:
--   1. pg_net 拡張が有効 (Supabase ではデフォルトで利用可能)
--   2. vault.secrets に 'service_role_key' という名前で
--      SERVICE_ROLE_KEY を保存済 — これは migration 外で手動実行:
--        SELECT vault.create_secret('<actual_service_role_key>', 'service_role_key');
--   3. SLACK_WEBHOOK_QUOTA env が core-hub に設定済 (Issue #696 S1 手動)
--
-- vault に key 未保存の場合、trigger は NOTICE を出して silent skip する
-- (本体の UPDATE 処理は影響受けない)。

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.notify_ai_circuit_breaker_open()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net, vault
AS $$
DECLARE
  v_service_key TEXT;
  v_supabase_url TEXT := 'https://smmkxxavexumewbfaqpy.supabase.co';
  v_message TEXT;
BEGIN
  -- closed → open 遷移のみ発火
  IF NOT (COALESCE(OLD.state, '') = 'closed' AND NEW.state = 'open') THEN
    RETURN NEW;
  END IF;

  -- vault から service_role_key を取得 (未設定なら silent skip)
  BEGIN
    SELECT decrypted_secret INTO v_service_key
      FROM vault.decrypted_secrets
      WHERE name = 'service_role_key'
      LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'vault.decrypted_secrets not accessible — circuit breaker Slack notify skipped';
    RETURN NEW;
  END;

  IF v_service_key IS NULL OR v_service_key = '' THEN
    RAISE NOTICE 'service_role_key not in vault — circuit breaker Slack notify skipped';
    RETURN NEW;
  END IF;

  -- Slack 投稿メッセージ組み立て
  v_message := format(
    ':fire: AI provider *%s* circuit breaker OPEN — reason: %s, expires: %s',
    NEW.provider,
    COALESCE(NEW.reason, 'unknown'),
    COALESCE(NEW.expires_at::TEXT, 'unknown')
  );

  -- pg_net 経由で core-hub:slack.notify 呼び出し (非同期 / fire-and-forget)
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/core-hub',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_service_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'action', 'slack.notify',
      'channel', 'quota',
      'text', v_message
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- trigger 内エラーは UPDATE 本体を阻害しない
  RAISE NOTICE 'circuit breaker Slack notify failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_circuit_breaker_open ON public.ai_circuit_breaker;

CREATE TRIGGER trg_notify_circuit_breaker_open
  AFTER UPDATE OF state ON public.ai_circuit_breaker
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_ai_circuit_breaker_open();

COMMENT ON FUNCTION public.notify_ai_circuit_breaker_open() IS
  'Issue #696 S3 — closed→open 遷移時に core-hub:slack.notify (channel=quota) で通知。Vault に service_role_key 必須。';
