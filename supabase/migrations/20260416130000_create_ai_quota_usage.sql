-- AI クォータ使用量監視テーブル
-- Windows版#63 2026-04-16
-- quota-monitor.yml が毎日 09:00 JST に書き込む

CREATE TABLE IF NOT EXISTS ai_quota_usage (
  id           bigserial PRIMARY KEY,
  tool         text NOT NULL,        -- 'anthropic' | 'openai' | 'github_copilot' | 'gemini'
  checked_at   date NOT NULL,        -- チェック日 (YYYY-MM-DD)
  usage_json   jsonb NOT NULL DEFAULT '{}'::jsonb,  -- 各ツールの使用量詳細
  alert        boolean NOT NULL DEFAULT false,       -- 閾値超過フラグ
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ユニーク制約: 同じツール・同じ日は1レコード (UPSERT 用)
CREATE UNIQUE INDEX IF NOT EXISTS ai_quota_usage_tool_date
  ON ai_quota_usage (tool, checked_at);

-- インデックス: 最新データ取得用
CREATE INDEX IF NOT EXISTS ai_quota_usage_checked_at
  ON ai_quota_usage (checked_at DESC);

-- RLS: SELECT は全ユーザー / INSERT・UPDATE はサービスロールのみ
ALTER TABLE ai_quota_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "quota_select_all"
  ON ai_quota_usage FOR SELECT
  USING (true);

CREATE POLICY "quota_write_service_role"
  ON ai_quota_usage FOR ALL
  USING (auth.role() = 'service_role');

-- コメント
COMMENT ON TABLE ai_quota_usage IS 'AI ツール (Claude/OpenAI/Gemini/Copilot) の日次クォータ使用量。quota-monitor.yml が毎日更新する。';
COMMENT ON COLUMN ai_quota_usage.tool IS 'anthropic | openai | github_copilot | gemini';
COMMENT ON COLUMN ai_quota_usage.usage_json IS '{"cost_usd": 12.34, "tokens": 1000000, "alert": false} など各ツール固有の使用量データ';
COMMENT ON COLUMN ai_quota_usage.alert IS '閾値超過時 true: Claude $50/月, OpenAI $20/月, Gemini 80% クォータ';
