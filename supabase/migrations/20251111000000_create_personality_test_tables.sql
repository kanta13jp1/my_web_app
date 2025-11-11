-- 性格診断機能のデータベーススキーマ
-- 作成日: 2025年11月11日
-- 目的: 16personalities.com風の性格診断機能でユーザー獲得を加速

-- 性格診断テストテーブル
CREATE TABLE IF NOT EXISTS personality_tests (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  personality_type TEXT, -- INTJ, INFP, etc.
  is_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- スコアテーブル（各軸のスコア）
CREATE TABLE IF NOT EXISTS personality_scores (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES personality_tests(id) ON DELETE CASCADE,
  axis TEXT NOT NULL, -- E/I, N/S, T/F, J/P, A/T
  score INTEGER NOT NULL, -- -100 to 100
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(test_id, axis)
);

-- 質問テーブル
CREATE TABLE IF NOT EXISTS personality_questions (
  id BIGSERIAL PRIMARY KEY,
  text TEXT NOT NULL,
  axis TEXT NOT NULL, -- E/I, N/S, T/F, J/P, A/T
  direction TEXT NOT NULL, -- A or B
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  order_num INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(order_num)
);

-- 回答テーブル
CREATE TABLE IF NOT EXISTS personality_answers (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES personality_tests(id) ON DELETE CASCADE,
  question_id BIGINT NOT NULL REFERENCES personality_questions(id) ON DELETE CASCADE,
  answer TEXT NOT NULL, -- A or B
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(test_id, question_id)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_personality_tests_user_id ON personality_tests(user_id);
CREATE INDEX IF NOT EXISTS idx_personality_tests_completed ON personality_tests(is_completed);
CREATE INDEX IF NOT EXISTS idx_personality_scores_test_id ON personality_scores(test_id);
CREATE INDEX IF NOT EXISTS idx_personality_answers_test_id ON personality_answers(test_id);

-- RLSポリシー
ALTER TABLE personality_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_answers ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のテストのみアクセス可能
CREATE POLICY "Users can view their own tests"
  ON personality_tests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tests"
  ON personality_tests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tests"
  ON personality_tests FOR UPDATE
  USING (auth.uid() = user_id);

-- 質問は全ユーザーが閲覧可能
CREATE POLICY "Anyone can view questions"
  ON personality_questions FOR SELECT
  USING (true);

-- ユーザーは自分の回答のみアクセス可能
CREATE POLICY "Users can view their own answers"
  ON personality_answers FOR SELECT
  USING (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own answers"
  ON personality_answers FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

-- スコアも同様
CREATE POLICY "Users can view their own scores"
  ON personality_scores FOR SELECT
  USING (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own scores"
  ON personality_scores FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

-- コメント
COMMENT ON TABLE personality_tests IS '性格診断テスト';
COMMENT ON TABLE personality_scores IS '性格診断スコア（各軸）';
COMMENT ON TABLE personality_questions IS '性格診断質問';
COMMENT ON TABLE personality_answers IS '性格診断回答';
