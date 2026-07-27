-- IQテスト + IQトレーニング機能のデータベーススキーマ
-- 作成日: 2026年7月27日
-- 目的: 認知能力の領域別測定と、その測定値を入力にした学習計画の管理
--
-- 設計メモ:
--   問題そのもの (問題文・選択肢・正解) はテーブルに置かない。
--   固定問題は lib/data/iq_question_bank.dart、トレーニング問題は
--   lib/data/iq_training_drills.dart で手続き生成する。
--   ここに保存するのは「結果」と「学習の進捗」だけ。
--   → 正解キーが誰でも SELECT できるテーブルに載るのを避けるため。

-- ============================================================ テスト実施記録
CREATE TABLE IF NOT EXISTS iq_tests (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  is_completed BOOLEAN NOT NULL DEFAULT false,

  -- 総合推定IQ。臨床的な規準ではない簡易推定である点はUI側で明示する。
  total_iq INTEGER,
  percentile NUMERIC(5, 2),
  weighted_accuracy NUMERIC(6, 5),
  correct_count INTEGER NOT NULL DEFAULT 0,
  question_count INTEGER NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,

  -- 選択肢シャッフルに使ったシード。結果の再現・監査用。
  question_seed INTEGER,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT iq_tests_total_iq_range
    CHECK (total_iq IS NULL OR (total_iq BETWEEN 40 AND 160)),
  CONSTRAINT iq_tests_percentile_range
    CHECK (percentile IS NULL OR (percentile BETWEEN 0 AND 100))
);

-- ============================================================ 領域別スコア
CREATE TABLE IF NOT EXISTS iq_category_scores (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES iq_tests(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  correct_count INTEGER NOT NULL DEFAULT 0,
  question_count INTEGER NOT NULL DEFAULT 0,
  weighted_accuracy NUMERIC(6, 5) NOT NULL DEFAULT 0,
  category_iq INTEGER NOT NULL DEFAULT 100,
  standard_error NUMERIC(6, 3) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (test_id, category),
  CONSTRAINT iq_category_scores_category_valid
    CHECK (category IN ('logic', 'numerical', 'spatial', 'memory', 'verbal'))
);

-- ============================================================ 個別回答
CREATE TABLE IF NOT EXISTS iq_answers (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES iq_tests(id) ON DELETE CASCADE,

  -- コード側の問題キー (例: logic-03)。外部キーではない。
  question_key TEXT NOT NULL,
  category TEXT NOT NULL,
  difficulty INTEGER NOT NULL,

  -- 時間切れの未回答は NULL。
  selected_index INTEGER,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  response_ms INTEGER NOT NULL DEFAULT 0,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (test_id, question_key),
  CONSTRAINT iq_answers_category_valid
    CHECK (category IN ('logic', 'numerical', 'spatial', 'memory', 'verbal')),
  CONSTRAINT iq_answers_difficulty_range CHECK (difficulty BETWEEN 1 AND 5)
);

-- ============================================================ 学習計画
CREATE TABLE IF NOT EXISTS iq_training_plans (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- どのテストの数値から作られた計画かを必ず辿れるようにする。
  source_test_id BIGINT NOT NULL REFERENCES iq_tests(id) ON DELETE CASCADE,
  baseline_iq INTEGER NOT NULL DEFAULT 100,

  -- [{category, baseline_iq, start_level, weekly_sessions}, ...]
  targets JSONB NOT NULL DEFAULT '[]'::jsonb,

  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================ 学習セッション
CREATE TABLE IF NOT EXISTS iq_training_sessions (
  id BIGSERIAL PRIMARY KEY,
  plan_id BIGINT NOT NULL REFERENCES iq_training_plans(id) ON DELETE CASCADE,

  -- plan 経由でも辿れるが、ユーザー単位の集計を軽くするため非正規化して持つ。
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  level INTEGER NOT NULL,
  correct_count INTEGER NOT NULL DEFAULT 0,
  question_count INTEGER NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT iq_training_sessions_category_valid
    CHECK (category IN ('logic', 'numerical', 'spatial', 'memory', 'verbal')),
  CONSTRAINT iq_training_sessions_level_range CHECK (level BETWEEN 1 AND 5)
);

-- ============================================================ インデックス
CREATE INDEX IF NOT EXISTS idx_iq_tests_user_id ON iq_tests(user_id);
-- 最新の完了テストを引く経路が最頻。部分インデックスで絞る。
CREATE INDEX IF NOT EXISTS idx_iq_tests_user_completed
  ON iq_tests(user_id, completed_at DESC)
  WHERE is_completed = true;
CREATE INDEX IF NOT EXISTS idx_iq_category_scores_test_id
  ON iq_category_scores(test_id);
CREATE INDEX IF NOT EXISTS idx_iq_answers_test_id ON iq_answers(test_id);
CREATE INDEX IF NOT EXISTS idx_iq_training_plans_user_active
  ON iq_training_plans(user_id, created_at DESC)
  WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_iq_training_sessions_plan
  ON iq_training_sessions(plan_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_iq_training_sessions_user_category
  ON iq_training_sessions(user_id, category, completed_at DESC);

-- ============================================================ RLS
ALTER TABLE iq_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE iq_category_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE iq_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE iq_training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE iq_training_sessions ENABLE ROW LEVEL SECURITY;

-- iq_tests: 本人のみ
CREATE POLICY "Users can view their own iq tests"
  ON iq_tests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own iq tests"
  ON iq_tests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own iq tests"
  ON iq_tests FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own iq tests"
  ON iq_tests FOR DELETE USING (auth.uid() = user_id);

-- iq_category_scores: 親テストの所有者のみ
CREATE POLICY "Users can view their own iq category scores"
  ON iq_category_scores FOR SELECT
  USING (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));
CREATE POLICY "Users can insert their own iq category scores"
  ON iq_category_scores FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));
CREATE POLICY "Users can update their own iq category scores"
  ON iq_category_scores FOR UPDATE
  USING (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()))
  WITH CHECK (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));

-- iq_answers: 親テストの所有者のみ
CREATE POLICY "Users can view their own iq answers"
  ON iq_answers FOR SELECT
  USING (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));
CREATE POLICY "Users can insert their own iq answers"
  ON iq_answers FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));
CREATE POLICY "Users can update their own iq answers"
  ON iq_answers FOR UPDATE
  USING (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()))
  WITH CHECK (test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid()));

-- iq_training_plans: 本人のみ
CREATE POLICY "Users can view their own iq training plans"
  ON iq_training_plans FOR SELECT USING (auth.uid() = user_id);
-- user_id だけでなく source_test_id の所有者も検証する。
-- 検証しないと他人のテストIDを指す計画を作れてしまい、
-- 「どの測定値から作られた計画か」の追跡可能性が壊れる。
CREATE POLICY "Users can insert their own iq training plans"
  ON iq_training_plans FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND source_test_id IN (SELECT id FROM iq_tests WHERE user_id = auth.uid())
  );
CREATE POLICY "Users can update their own iq training plans"
  ON iq_training_plans FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own iq training plans"
  ON iq_training_plans FOR DELETE USING (auth.uid() = user_id);

-- iq_training_sessions: 本人のみ
CREATE POLICY "Users can view their own iq training sessions"
  ON iq_training_sessions FOR SELECT USING (auth.uid() = user_id);
-- user_id だけの検証では、他人の plan_id を指す行を自分名義で挿入できてしまう。
-- 現在の読み出し経路 (user_id で絞る) では露出しないが、plan_id で集計する
-- 処理を将来足したときに他人の計画へ混入する。所有者チェックを併せて課す。
CREATE POLICY "Users can insert their own iq training sessions"
  ON iq_training_sessions FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND plan_id IN (SELECT id FROM iq_training_plans WHERE user_id = auth.uid())
  );
CREATE POLICY "Users can delete their own iq training sessions"
  ON iq_training_sessions FOR DELETE USING (auth.uid() = user_id);

-- ============================================================ コメント
COMMENT ON TABLE iq_tests IS 'IQテストの実施記録と総合推定スコア (簡易推定であり臨床規準ではない)';
COMMENT ON TABLE iq_category_scores IS 'IQテストの領域別スコア。学習計画の入力になる';
COMMENT ON TABLE iq_answers IS 'IQテストの個別回答。問題本体はコード側に持つ';
COMMENT ON TABLE iq_training_plans IS 'テスト結果から生成された学習計画';
COMMENT ON TABLE iq_training_sessions IS 'トレーニング1回分の記録。レベル調整の入力になる';
COMMENT ON COLUMN iq_tests.question_seed IS '選択肢シャッフルのシード。結果再現用';
COMMENT ON COLUMN iq_training_plans.targets IS
  '[{category, baseline_iq, start_level, weekly_sessions}, ...]';
