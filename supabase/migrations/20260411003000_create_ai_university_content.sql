-- AI大学コンテンツテーブル
-- 6大AIプロバイダー (Google/OpenAI/Anthropic/Microsoft/Meta/X) の
-- 最新情報を毎週 Claude Schedule が自動取得・更新する
CREATE TABLE IF NOT EXISTS ai_university_content (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider      text NOT NULL,        -- 'google' | 'openai' | 'anthropic' | 'microsoft' | 'meta' | 'x'
  category      text NOT NULL,        -- 'models' | 'api' | 'pricing' | 'news' | 'tutorial' | 'overview'
  title         text NOT NULL,
  content       text NOT NULL,        -- Markdown 形式
  source_url    text,                 -- 参照元URL
  published_at  date,                 -- コンテンツの公開日
  sort_order    int  NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- インデックス: プロバイダー別・カテゴリ別表示用
CREATE INDEX IF NOT EXISTS ai_university_content_provider_idx
  ON ai_university_content (provider, sort_order);

CREATE INDEX IF NOT EXISTS ai_university_content_category_idx
  ON ai_university_content (category, updated_at DESC);

-- RLS: 全ユーザー閲覧可・更新はサービスロールのみ
ALTER TABLE ai_university_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_university_content_select_all" ON ai_university_content
  FOR SELECT USING (is_active = true);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_ai_university_updated_at()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ai_university_updated_at
  BEFORE UPDATE ON ai_university_content
  FOR EACH ROW EXECUTE FUNCTION update_ai_university_updated_at();
