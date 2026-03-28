-- Edge Function UI ステータステーブル
-- edge-function-audit.yml GitHub Actions が毎時更新する
CREATE TABLE IF NOT EXISTS edge_function_ui_status (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  function_name text        NOT NULL UNIQUE,
  has_ui_caller boolean     NOT NULL DEFAULT false,
  caller_file   text,
  last_checked  timestamptz DEFAULT now() NOT NULL,
  updated_at    timestamptz DEFAULT now() NOT NULL
);

-- RLS: 認証済みユーザーは読み取り可、service_role のみ書き込み可
ALTER TABLE edge_function_ui_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "edge_function_ui_status_read" ON edge_function_ui_status
  FOR SELECT
  USING (true);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_edge_function_ui_status_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER edge_function_ui_status_updated_at
  BEFORE UPDATE ON edge_function_ui_status
  FOR EACH ROW EXECUTE FUNCTION update_edge_function_ui_status_updated_at();
