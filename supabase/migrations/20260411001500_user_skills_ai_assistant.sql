-- Session Web版: ai-assistant マイスキル登録・再利用機能 (Slack AI 対抗)
-- user_skills: ユーザーが保存したAIプロンプトテンプレート (再利用スキル)

CREATE TABLE IF NOT EXISTS user_skills (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text        NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
  description      text        CHECK (length(description) <= 300),
  prompt_template  text        NOT NULL CHECK (length(trim(prompt_template)) > 0),
  model            text,
  tags             text[]      DEFAULT '{}',
  use_count        integer     NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- 1ユーザーあたりのスキル名はユニーク
CREATE UNIQUE INDEX IF NOT EXISTS user_skills_user_name_idx
  ON user_skills (user_id, name);

-- 検索・一覧用インデックス
CREATE INDEX IF NOT EXISTS user_skills_user_id_created_idx
  ON user_skills (user_id, created_at DESC);

-- RLS: 自分のスキルのみ操作可能
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own skills"
  ON user_skills FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own skills"
  ON user_skills FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own skills"
  ON user_skills FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own skills"
  ON user_skills FOR DELETE USING (auth.uid() = user_id);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_user_skills_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_user_skills_updated_at
  BEFORE UPDATE ON user_skills
  FOR EACH ROW EXECUTE FUNCTION update_user_skills_updated_at();

-- achievement seed
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AIマイスキル登録・再利用機能',
  'Slack AI 再利用スキル対抗: ユーザーが名前付きプロンプトテンプレートを登録・再利用できるスキル管理機能を追加。save_skill / list_skills / delete_skill / run_skill の4アクションをai-assistant EFに実装。',
  '2026-04-11'
)
ON CONFLICT DO NOTHING;
