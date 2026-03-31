-- Session 427: A/B Testing テーブル + data-export-manager + ab-testing-manager 実績

-- A/B 実験テーブル
CREATE TABLE IF NOT EXISTS ab_experiments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text DEFAULT '',
  variants jsonb NOT NULL DEFAULT '["control","variant_a"]',
  target_metric text DEFAULT 'conversion',
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- A/B 割り当てテーブル
CREATE TABLE IF NOT EXISTS ab_assignments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  experiment_id uuid NOT NULL REFERENCES ab_experiments(id),
  user_id uuid NOT NULL,
  variant text NOT NULL,
  converted boolean DEFAULT false,
  converted_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE (experiment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_ab_assignments_experiment ON ab_assignments (experiment_id);
CREATE INDEX IF NOT EXISTS idx_ab_assignments_user ON ab_assignments (user_id);

-- 実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Data Export Manager Edge Function 追加', 'GDPR対応ユーザーデータエクスポート。JSON/CSV 形式、プロフィール/ノート/リクエスト/通知の一括エクスポート', '2026-03-31'),
  ('A/B Testing Manager Edge Function 追加', '機能実験管理。実験作成・バリアント自動割り当て・コンバージョン記録・結果統計。ab_experiments + ab_assignments テーブル', '2026-03-31')
ON CONFLICT DO NOTHING;
