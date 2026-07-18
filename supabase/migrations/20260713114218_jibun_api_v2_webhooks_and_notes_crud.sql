-- 自分API v2: アウトバウンド Webhook サブスクリプション + Notes CRUD
-- Notion Developer Platform / Webhook triggers 対抗 (2026-07-13 WEB版)

-- ── user_api_webhooks ────────────────────────────────────────────────────────
-- 外部エージェントが 自分 イベントを受け取るための Outbound Webhook 登録テーブル。
-- Notion の "Webhook triggers" 相当機能。

CREATE TABLE IF NOT EXISTS user_api_webhooks (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  endpoint_url     text        NOT NULL,
  signing_secret   text        NOT NULL,
  events           text[]      NOT NULL DEFAULT '{}',
  enabled          boolean     NOT NULL DEFAULT true,
  delivery_count   bigint      NOT NULL DEFAULT 0,
  last_delivered_at timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_api_webhooks_user_id_idx
  ON user_api_webhooks (user_id);

CREATE INDEX IF NOT EXISTS user_api_webhooks_events_idx
  ON user_api_webhooks USING gin (events);

ALTER TABLE user_api_webhooks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own webhooks"
  ON user_api_webhooks
  FOR ALL
  USING (auth.uid() = user_id);

-- Service role はポリシーをバイパスするため追加ポリシー不要。

-- ── notes: updated_at カラム保証 ──────────────────────────────────────────────
-- api.notes.update で updated_at を更新するため、カラムが存在しない場合に追加する。

ALTER TABLE notes ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- ── コメント ─────────────────────────────────────────────────────────────────

COMMENT ON TABLE user_api_webhooks IS
  'アウトバウンド Webhook サブスクリプション — 自分API v2 (Notion Webhook triggers 対抗)';
COMMENT ON COLUMN user_api_webhooks.events IS
  '購読イベント種別: note.created / note.updated / note.deleted';
COMMENT ON COLUMN user_api_webhooks.signing_secret IS
  'HMAC-SHA256 署名シークレット (jibun_whsec_... / 平文は登録時のみ返却)';
