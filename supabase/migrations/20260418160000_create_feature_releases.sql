-- feature_releases: 最近追加された機能 (5-tier home Layer 4)
CREATE TABLE IF NOT EXISTS feature_releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_route text NOT NULL,
  feature_label text NOT NULL,
  description text,
  released_at timestamptz DEFAULT now(),
  category text
);

CREATE INDEX IF NOT EXISTS idx_feature_releases_released_at
  ON feature_releases(released_at DESC);

ALTER TABLE feature_releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone can read feature releases"
  ON feature_releases FOR SELECT
  USING (true);

CREATE POLICY "admins can manage feature releases"
  ON feature_releases FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- 初期データ: 最近追加された主要機能
INSERT INTO feature_releases (feature_route, feature_label, description, released_at, category) VALUES
  ('/ai-university', 'AI大学', '84社のAIプロバイダーを学習できる機能', now() - interval '3 days', 'learning'),
  ('/note-list', 'ノート', 'タグ機能・AI自動タグ付けに対応', now() - interval '5 days', 'productivity'),
  ('/ai-provider-status', 'AIプロバイダー状況', 'Tier badge付き84社一覧', now() - interval '7 days', 'ai'),
  ('/wbs', 'WBSプロジェクト管理', 'ガントチャート付きWBS', now() - interval '10 days', 'business')
ON CONFLICT DO NOTHING;
