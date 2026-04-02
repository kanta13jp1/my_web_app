-- Session 432p: Edge Functions 185→190 (referral, analytics-export, workflow, status, address-book)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('referral-program Edge Function', '紹介プログラム機能 — 紹介コード自動生成・紹介追跡・報酬管理(プレミアム日数)・リーダーボード (ユーザー獲得戦略)', '2026-04-01'),
  ('analytics-export Edge Function', '分析データエクスポート機能 — レポート生成・CSV/JSON/Markdown形式・スケジュールレポート・メール配信 (Google Analytics/Microsoft競合)', '2026-04-01'),
  ('workflow-templates Edge Function', 'ワークフローテンプレート機能 — 経費承認/オンボーディング/バグ修正等テンプレート・ステップ管理・承認フロー (Notion/Slack/ジョブカン競合)', '2026-04-01'),
  ('status-page Edge Function', 'ステータスページ機能 — 8コンポーネント監視・インシデント記録・メンテナンス予定・稼働率計算 (GitHub Status/Statuspage競合)', '2026-04-01'),
  ('address-book Edge Function', 'アドレス帳機能 — 連絡先管理・グループ分け・ラベル・vCardエクスポート・重複検出 (Google Contacts/Outlook競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
