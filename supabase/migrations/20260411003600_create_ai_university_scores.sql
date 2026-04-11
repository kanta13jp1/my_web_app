-- AI大学スコア・ランキングテーブル
-- ユーザーのクイズ正解数・連続学習日数・最終学習日を管理する

CREATE TABLE IF NOT EXISTS ai_university_scores (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id   text        NOT NULL,                -- 'google' | 'openai' | 'deepseek' etc.
  quiz_correct  boolean     NOT NULL DEFAULT false,  -- そのプロバイダーのクイズを正解したか
  studied_at    timestamptz NOT NULL DEFAULT now(),  -- 最終学習日時
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider_id)
);

-- ランキング集計用ビュー (全プロバイダー合計正解数)
CREATE OR REPLACE VIEW ai_university_leaderboard AS
SELECT
  u.id                            AS user_id,
  u.email                         AS display_name,
  COUNT(*) FILTER (WHERE s.quiz_correct)::int AS total_correct,
  COUNT(DISTINCT s.provider_id)   AS providers_studied,
  MAX(s.studied_at)               AS last_studied_at,
  RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE s.quiz_correct) DESC) AS rank
FROM auth.users u
LEFT JOIN ai_university_scores s ON s.user_id = u.id
GROUP BY u.id, u.email
ORDER BY total_correct DESC;

-- RLS
ALTER TABLE ai_university_scores ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のスコアのみ読み書き可能
CREATE POLICY "users_own_scores" ON ai_university_scores
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ランキングは全員閲覧可能
GRANT SELECT ON ai_university_leaderboard TO anon, authenticated;

-- インデックス
CREATE INDEX IF NOT EXISTS idx_ai_univ_scores_user ON ai_university_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_univ_scores_correct ON ai_university_scores(quiz_correct);

-- 開発実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学ランキング機能 実装',
  'ai_university_scores テーブル + leaderboard ビュー作成。ユーザーのクイズ正解をDB保存しランキング表示を可能に。',
  '2026-04-11'
)
ON CONFLICT DO NOTHING;
