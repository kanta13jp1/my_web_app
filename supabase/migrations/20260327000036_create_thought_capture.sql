-- 思考キャプチャ: 浮かんだ思考を即座に捕まえて消えないようにする
-- ワンタップで記録 → 後で整理・深掘り

-- 思考キャプチャテーブル
CREATE TABLE IF NOT EXISTS thought_captures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 思考の内容 (最小限で即記録)
  content text NOT NULL,
  -- タグ (後から分類)
  tags text[] DEFAULT '{}',
  -- 種類: idea(ひらめき), worry(不安), todo(やること), insight(気づき), random(雑念)
  thought_type text NOT NULL DEFAULT 'random' CHECK (thought_type IN (
    'idea', 'worry', 'todo', 'insight', 'random', 'question', 'memory'
  )),
  -- 重要度 1-5 (後で設定可)
  importance int DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
  -- 処理ステータス: captured(捕獲), reviewed(振り返り済み), acted(行動済み), archived(保管)
  status text NOT NULL DEFAULT 'captured' CHECK (status IN (
    'captured', 'reviewed', 'acted', 'archived', 'discarded'
  )),
  -- 深掘りメモ (後で追記)
  reflection text,
  -- 関連する人生目標 (あれば紐付け)
  linked_goal_id uuid REFERENCES life_goals(id) ON DELETE SET NULL,
  -- いつ浮かんだか
  captured_at timestamptz NOT NULL DEFAULT now(),
  -- 処理した日時
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE thought_captures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own thought captures"
  ON thought_captures FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on thought_captures"
  ON thought_captures FOR ALL
  USING (auth.role() = 'service_role');

-- Indexes
CREATE INDEX idx_thought_captures_user_status ON thought_captures(user_id, status, captured_at DESC);
CREATE INDEX idx_thought_captures_type ON thought_captures(user_id, thought_type);
CREATE INDEX idx_thought_captures_recent ON thought_captures(user_id, captured_at DESC);

-- 思考の連鎖テーブル (関連する思考を繋げる)
CREATE TABLE IF NOT EXISTS thought_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_thought_id uuid NOT NULL REFERENCES thought_captures(id) ON DELETE CASCADE,
  to_thought_id uuid NOT NULL REFERENCES thought_captures(id) ON DELETE CASCADE,
  connection_type text DEFAULT 'related' CHECK (connection_type IN (
    'related', 'caused_by', 'leads_to', 'contradicts', 'supports'
  )),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(from_thought_id, to_thought_id)
);

ALTER TABLE thought_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage thought connections via captures"
  ON thought_connections FOR ALL
  USING (EXISTS (
    SELECT 1 FROM thought_captures
    WHERE thought_captures.id = thought_connections.from_thought_id
    AND thought_captures.user_id = auth.uid()
  ));

CREATE POLICY "Service role full access on thought_connections"
  ON thought_connections FOR ALL
  USING (auth.role() = 'service_role');

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '思考キャプチャ機能を追加',
  '浮かんだ思考を即座に記録し、後で整理・深掘り・人生目標に紐付け。思考の連鎖も管理可能。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
