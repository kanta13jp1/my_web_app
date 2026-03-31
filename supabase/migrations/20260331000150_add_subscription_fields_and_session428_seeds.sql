-- Session 428: サブスクリプション管理用カラム追加 + 実績シード

-- user_profiles にサブスクリプション関連カラム追加
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'subscription_plan') THEN
    ALTER TABLE user_profiles ADD COLUMN subscription_plan text DEFAULT 'free';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'subscription_expires_at') THEN
    ALTER TABLE user_profiles ADD COLUMN subscription_expires_at timestamptz;
  END IF;
END $$;

-- 実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Subscription Management Edge Function 追加', 'Free/Pro(¥480)/Premium(¥980) プラン管理、利用量クォータ追跡、収益サマリー', '2026-03-31'),
  ('Gamification Engine Edge Function 追加', 'デイリーストリーク・13種バッジ・ポイントシステム・リーダーボード', '2026-03-31'),
  ('Agent Task Router Edge Function 追加', 'AIエージェント間のインテリジェントタスク自動割り振り、部署スキルマッチング、負荷分散、エスカレーション', '2026-03-31'),
  ('Import From Competitors Edge Function 追加', '8形式対応の競合製品データインポート (Notion/Evernote/MoneyForward/Google Keep/Slack/Chatwork/Markdown/CSV)', '2026-03-31'),
  ('Department Reporting Edge Function 追加', '部署別KPIレポート、完了率・効率スコア算出、全社サマリー', '2026-03-31'),
  ('Agent Performance Monitor Edge Function 追加', 'エージェント個別パフォーマンス監視、ランキング、低パフォーマンスアラート', '2026-03-31')
ON CONFLICT DO NOTHING;
