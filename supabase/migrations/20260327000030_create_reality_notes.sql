-- 現実直視ノート: 事実から目をそむけず記録・分類・行動に変える
CREATE TABLE IF NOT EXISTS reality_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 記録した「現実」
  raw_text text NOT NULL,
  -- 分類: fact(客観的事実) / interpretation(主観的解釈) / emotion(感情)
  classification text NOT NULL DEFAULT 'fact' CHECK (classification IN ('fact', 'interpretation', 'emotion')),
  -- カテゴリ: geopolitics(地政学), economy(経済), career(仕事), relationship(人間関係), health(健康), self(自己), other(その他)
  category text NOT NULL DEFAULT 'other',
  -- この現実に対して自分が取れる行動
  action_plan text,
  -- 行動を実行したか
  action_done boolean NOT NULL DEFAULT false,
  action_done_at timestamptz,
  -- AIによる考察（事実と解釈の区別、認知の歪みの指摘等）
  ai_analysis text,
  -- 重要度 1-5
  severity int NOT NULL DEFAULT 3 CHECK (severity BETWEEN 1 AND 5),
  -- 定期的に見直すかどうか
  review_interval text DEFAULT 'weekly' CHECK (review_interval IN ('daily', 'weekly', 'monthly', 'once')),
  next_review_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE reality_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own reality notes"
  ON reality_notes FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- service role full access
CREATE POLICY "Service role full access on reality_notes"
  ON reality_notes FOR ALL
  USING (auth.role() = 'service_role');

-- Index
CREATE INDEX idx_reality_notes_user_category ON reality_notes(user_id, category);
CREATE INDEX idx_reality_notes_review ON reality_notes(user_id, next_review_at) WHERE action_done = false;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '現実直視ノート機能を追加',
  '事実から目をそむけず記録・AI分析で「事実/解釈/感情」を分類・行動計画に変換する機能。定期レビュー機能付き。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
