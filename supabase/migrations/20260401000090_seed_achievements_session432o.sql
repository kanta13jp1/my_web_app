-- Session 432o: Edge Functions 180→185 (data-viz, api-docs, backup, notification-digest, smart-search)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('data-visualization Edge Function', 'データ可視化・チャート生成機能 — 10種チャートタイプ・ダッシュボード構成・カラーパレット・データソース連携 (Google Sheets/Notion競合)', '2026-04-01'),
  ('api-docs-generator Edge Function', 'APIドキュメント自動生成機能 — エンドポイント登録・リクエスト/レスポンス例・OpenAPI形式エクスポート (GitHub/Swagger競合)', '2026-04-01'),
  ('backup-restore Edge Function', 'バックアップ・リストア管理機能 — バックアップ作成・自動スケジュール・エクスポート形式選択・統計 (Google Drive/Dropbox競合)', '2026-04-01'),
  ('notification-digest Edge Function', '通知ダイジェスト機能 — 通知集約・カテゴリ別グルーピング・優先度フィルタ・静音時間・チャネル設定 (Slack/Discord競合)', '2026-04-01'),
  ('smart-search Edge Function', 'スマート検索機能 — 全文検索・マルチソース横断・フィルタ条件・検索履歴・保存済み検索・サジェスト (Google/Notion/Evernote競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
