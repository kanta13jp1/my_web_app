-- Session 432m: Edge Functions 170→175 (appointment, password, gamification, inventory, feedback)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('appointment-scheduler Edge Function', '予約スケジューラー機能 — 予約枠設定・受付・確認・リマインダー・キャンセル・統計 (Google Calendar/Calendly競合)', '2026-04-01'),
  ('password-vault Edge Function', 'パスワード管理機能 — パスワード保存・強度チェック・セキュリティ監査・パスワード生成・カテゴリ管理 (1Password/LastPass競合)', '2026-04-01'),
  ('habit-gamification Edge Function', '習慣ゲーミフィケーション機能 — デイリーチャレンジ・実績バッジ12種・レベル/経験値・ランキング・ストリーク管理 (Duolingo/Forest競合)', '2026-04-01'),
  ('inventory-barcode Edge Function', '在庫バーコード管理機能 — バーコードスキャン・入出庫記録・棚卸し・在庫アラート・在庫レポート (Amazon/ジョブカン競合)', '2026-04-01'),
  ('customer-feedback Edge Function', '顧客フィードバック・NPS管理機能 — フィードバック収集・NPS調査・感情分析・分類・トレンド分析 (Slack/Intercom競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
