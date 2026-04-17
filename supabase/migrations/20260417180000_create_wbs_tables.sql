-- WBS (Work Breakdown Structure) テーブル
-- 自分株式会社 開発ロードマップをサイト上で可視化するためのテーブル

-- リリースマイルストーン
CREATE TABLE IF NOT EXISTS wbs_milestones (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code       text UNIQUE NOT NULL,       -- 'alpha', 'beta', 'v1'
  name       text NOT NULL,              -- 'α版', 'β版', '最終版 v1.0'
  target_date date NOT NULL,
  goal_users int NOT NULL DEFAULT 0,     -- ユーザー数目標
  description text,
  color      text NOT NULL DEFAULT '#FF6B35',
  achieved_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- WBSタスク
CREATE TABLE IF NOT EXISTS wbs_tasks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category       text NOT NULL,          -- カテゴリ名
  category_icon  text NOT NULL DEFAULT '📋',
  category_order int  NOT NULL DEFAULT 0,
  title          text NOT NULL,
  description    text,
  instance       text NOT NULL DEFAULT 'all',  -- vscode/windows/ps/all
  status         text NOT NULL DEFAULT 'pending',  -- pending/in_progress/completed/blocked
  progress       int  NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  start_date     date,
  end_date       date,
  milestone_code text REFERENCES wbs_milestones(code),
  priority       text NOT NULL DEFAULT 'medium',  -- high/medium/low
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- RLS: 全員読み取り可 (公開開発状況)
ALTER TABLE wbs_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE wbs_tasks      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wbs_milestones_read" ON wbs_milestones FOR SELECT USING (true);
CREATE POLICY "wbs_tasks_read"      ON wbs_tasks      FOR SELECT USING (true);

-- 管理者のみ書き込み可
CREATE POLICY "wbs_milestones_admin_write" ON wbs_milestones FOR ALL
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));
CREATE POLICY "wbs_tasks_admin_write" ON wbs_tasks FOR ALL
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION update_wbs_tasks_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER wbs_tasks_updated_at BEFORE UPDATE ON wbs_tasks
  FOR EACH ROW EXECUTE FUNCTION update_wbs_tasks_updated_at();
