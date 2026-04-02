-- Session 432q: Edge Functions 190→195 (i18n, data-pipeline, billing, feature-flags, audit)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('multi-language Edge Function', '多言語対応(i18n)機能 — 10言語サポート・翻訳キー管理・言語切替・翻訳進捗・ユーザー言語設定 (Google/Microsoft/Notion競合)', '2026-04-01'),
  ('data-pipeline Edge Function', 'データパイプライン(ETL)機能 — データソース定義・変換ルール7種・パイプライン実行・スケジュール・実行ログ (Google Cloud/Azure競合)', '2026-04-01'),
  ('subscription-billing Edge Function', 'サブスクリプション課金管理機能 — Free/Starter/Pro/Enterprise 4プラン・請求書生成・クーポン・使用量制限 (Amazon/Slack/Microsoft競合)', '2026-04-01'),
  ('feature-flags Edge Function', 'フィーチャーフラグ管理機能 — ブール/パーセンテージ/ユーザーリスト型・ロールアウト制御・フラグ評価API (GitHub/LaunchDarkly競合)', '2026-04-01'),
  ('audit-trail Edge Function', '監査ログ管理機能 — アクション記録・ユーザーアクティビティ追跡・コンプライアンスレポート・検索/フィルタ (Google Workspace/Microsoft 365/GitHub競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
