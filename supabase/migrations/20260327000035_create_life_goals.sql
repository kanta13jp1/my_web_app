-- 人生目標管理: 大目標 → 中目標 → 小目標（毎日の行動）に分解
-- ツリー構造で目標を管理し、進捗を自動集計する

-- 人生目標テーブル（ツリー構造）
CREATE TABLE IF NOT EXISTS life_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  -- ツリー構造
  parent_id uuid REFERENCES life_goals(id) ON DELETE CASCADE,
  -- レベル: dream(人生の夢), big(大目標), medium(中目標), small(小目標/日常行動)
  level text NOT NULL DEFAULT 'big' CHECK (level IN ('dream', 'big', 'medium', 'small')),
  -- 目標内容
  title text NOT NULL,
  description text,
  -- カテゴリ
  category text NOT NULL DEFAULT 'other' CHECK (category IN (
    'career', 'finance', 'relationship', 'health', 'education',
    'lifestyle', 'creative', 'social', 'spiritual', 'other'
  )),
  -- 期限
  target_date date,
  -- 進捗 (small目標は手動、上位は子の平均で自動計算)
  progress int NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  -- ステータス
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'abandoned')),
  completed_at timestamptz,
  -- 優先度 1-5
  priority int NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  -- 繰り返し (small目標用): daily, weekly, monthly, once
  recurrence text DEFAULT 'once' CHECK (recurrence IN ('daily', 'weekly', 'monthly', 'once')),
  -- メモ・振り返り
  notes text,
  -- 表示順
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE life_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own life goals"
  ON life_goals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on life_goals"
  ON life_goals FOR ALL
  USING (auth.role() = 'service_role');

-- Indexes
CREATE INDEX idx_life_goals_user ON life_goals(user_id, level, status);
CREATE INDEX idx_life_goals_parent ON life_goals(parent_id);
CREATE INDEX idx_life_goals_category ON life_goals(user_id, category);

-- 目標マイルストーン（中間チェックポイント）
CREATE TABLE IF NOT EXISTS life_goal_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES life_goals(id) ON DELETE CASCADE,
  title text NOT NULL,
  target_date date,
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE life_goal_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage milestones via goals"
  ON life_goal_milestones FOR ALL
  USING (EXISTS (
    SELECT 1 FROM life_goals WHERE life_goals.id = life_goal_milestones.goal_id AND life_goals.user_id = auth.uid()
  ));

CREATE POLICY "Service role full access on life_goal_milestones"
  ON life_goal_milestones FOR ALL
  USING (auth.role() = 'service_role');

-- 目標の振り返りログ
CREATE TABLE IF NOT EXISTS life_goal_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES life_goals(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 振り返り内容
  reflection text NOT NULL,
  -- 前回からの進捗変化
  progress_before int,
  progress_after int,
  -- 気分 1-5
  mood int CHECK (mood BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE life_goal_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own goal reviews"
  ON life_goal_reviews FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on life_goal_reviews"
  ON life_goal_reviews FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_life_goal_reviews_goal ON life_goal_reviews(goal_id, created_at DESC);

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '人生目標管理機能を追加',
  '大目標→中目標→小目標のツリー構造で目標を管理。マイルストーン、定期振り返り、進捗自動集計機能付き。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
