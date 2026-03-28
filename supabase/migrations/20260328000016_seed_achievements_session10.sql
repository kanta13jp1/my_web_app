-- Session daily-development session10 (Web instance): Edge Function 拡張
INSERT INTO development_achievements (title, description, completed_at)
VALUES
(
  'get-competitor-monitoring Edge Function 新規作成',
  'competitor_monitoring テーブルから競合14社のWeb可用性データをGETで取得できる新規 Edge Function。anon キーでアクセス可能。 ?limit=N&days=N&competitor=key パラメータ対応。管理者ダッシュボードの競合モニタリングUIと連携するためのバックエンド実装。',
  '2026-03-28'
),
(
  'CI/CD Edge Functions デプロイ全数対応',
  'deploy-prod.yml の Edge Functions デプロイ対象に check-competitor-updates / get-competitor-monitoring / health-check / analyze-reality / trigger-analysis / local-election-intelligence / agent-runtime-cycle の 7 関数を追加。全 Edge Functions の本番自動デプロイが完備。',
  '2026-03-28'
)
ON CONFLICT DO NOTHING;
