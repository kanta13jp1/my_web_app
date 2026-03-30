-- Business Intelligence: 競合・参入市場トラッキングテーブル
-- Real Value YouTube等で取り上げられるビジネスカテゴリを管理する

CREATE TABLE IF NOT EXISTS business_intelligence (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category      text NOT NULL,           -- ビジネスカテゴリ (e.g. 'saas', 'fintech', 'edtech')
  competitor    text NOT NULL,           -- 競合名
  source        text,                    -- 情報ソース ('real_value_youtube', 'direct', 'news')
  market_size   text,                    -- 市場規模の概算 (e.g. '1兆円規模')
  our_feature   text,                    -- 当社の対抗機能
  gap_analysis  text,                    -- 差分分析
  priority      int NOT NULL DEFAULT 5,  -- 優先度 1-10 (10が最高)
  status        text NOT NULL DEFAULT 'tracking', -- tracking / competing / won / paused
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE business_intelligence ENABLE ROW LEVEL SECURITY;

-- 認証済みユーザーは読み取り可能
CREATE POLICY "Authenticated can read business_intelligence"
  ON business_intelligence FOR SELECT
  TO authenticated
  USING (true);

-- service_role は全操作可能
CREATE POLICY "service_role_business_intelligence"
  ON business_intelligence FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 管理者は全操作可能
CREATE POLICY "admin_all_business_intelligence"
  ON business_intelligence FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.user_id = auth.uid() AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.user_id = auth.uid() AND up.is_admin = true
    )
  );

CREATE INDEX IF NOT EXISTS idx_business_intelligence_category ON business_intelligence(category);
CREATE INDEX IF NOT EXISTS idx_business_intelligence_priority ON business_intelligence(priority DESC);

-- 既存21競合のシードデータ
INSERT INTO business_intelligence (category, competitor, source, market_size, our_feature, priority, status) VALUES
  ('knowledge_management', 'Notion', 'direct', 'グローバル1000億円超', 'AI統合ノート・タスク・Wiki', 10, 'competing'),
  ('knowledge_management', 'Evernote', 'direct', '日本市場縮小中', 'インポート移行・AI強化ノート', 8, 'competing'),
  ('finance', 'MoneyForward', 'direct', '日本フィンテック最大手', '支出追跡・予算管理統合', 9, 'competing'),
  ('sns', 'X (Twitter)', 'direct', 'グローバルSNS大手', '公開メモ・SNSシェア・X投稿自動化', 8, 'competing'),
  ('ai_tools', 'Animaworks', 'direct', 'AI特化ニッチ市場', 'マルチAIエージェント統合', 6, 'competing'),
  ('ai_dev_tools', 'Claude Code', 'direct', 'AI開発ツール急成長', 'AI秘書・開発支援統合', 9, 'competing'),
  ('ai_dev_tools', 'Codex', 'direct', 'AI開発ツール', 'コード生成・タスク自動化', 7, 'competing'),
  ('horse_racing', 'netkeiba', 'direct', '競馬情報No.1', 'AI予測・レース分析', 5, 'tracking'),
  ('project_management', 'OpenClaw', 'direct', 'プロジェクト管理ニッチ', 'AI組織管理・エージェントOS', 6, 'competing'),
  ('remote_work', 'Claude Cowork', 'direct', 'AI協働ツール', 'チームワークスペース・AI会議', 7, 'competing'),
  ('business_chat', 'Chatwork', 'direct', '日本BizChat市場', 'チャット+タスク+AI統合', 8, 'competing'),
  ('business_chat', 'Slack', 'direct', 'グローバルBizChat', 'AI統合チャネル・ワークフロー', 9, 'competing'),
  ('hr_payroll', 'ジョブカン', 'direct', '日本HR SaaS', '勤怠・給与・人事AI統合', 7, 'competing'),
  ('ecommerce', 'Amazon', 'direct', 'グローバルEC最大手', 'ショッピングリスト・価格追跡', 6, 'tracking'),
  ('platform', 'Google', 'direct', 'グローバルプラットフォーム', 'AI検索・Workspace代替', 10, 'competing'),
  ('platform', 'Microsoft', 'direct', 'エンタープライズ最大手', 'Office代替・Teams統合', 9, 'competing'),
  ('gaming_community', 'Discord', 'direct', 'コミュニティプラットフォーム', 'チームコミュニティ・音声会議', 7, 'competing'),
  ('sns_messaging', 'LINE', 'direct', '日本メッセージングNo.1', 'AI通知・メッセージ統合', 9, 'competing'),
  ('sns', 'Facebook', 'direct', 'グローバルSNS', 'コミュニティ・グループ管理', 7, 'competing'),
  ('lifestyle', 'Liven', 'direct', 'ライフスタイルアプリ', '健康・習慣・ライフマネジメント', 6, 'competing'),
  ('developer_tools', 'GitHub', 'direct', 'コード管理No.1', 'プロジェクト追跡・CI/CD統合', 8, 'competing')
ON CONFLICT DO NOTHING;
