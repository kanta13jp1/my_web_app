-- Session 432l: Edge Functions 165→170 (auction, budget, code-playground, screen-recorder, qr-code)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('auction-marketplace Edge Function', 'オークション・マーケットプレイス機能 — 出品管理・入札・即決・取引メッセージ・評価レビュー・売上統計 (Amazon/メルカリ競合)', '2026-04-01'),
  ('budget-financial-planner Edge Function', '予算・家計プランナー機能 — 月次予算設定・カテゴリ別支出管理・収入記録・貯蓄目標・キャッシュフロー分析・家計診断 (MoneyForward競合強化)', '2026-04-01'),
  ('code-playground Edge Function', 'コードプレイグラウンド機能 — 20言語対応スニペット管理・テンプレート・共有リンク・コレクション・フォーク・実行ログ (Claude Code/Codex/GitHub競合)', '2026-04-01'),
  ('screen-recorder Edge Function', '画面録画・スクリーンショット管理機能 — 録画メタデータ・スクリーンショット・アノテーション・共有リンク・ストレージ統計 (Discord/Zoom/Loom競合)', '2026-04-01'),
  ('qr-code-generator Edge Function', 'QRコード生成・管理機能 — URL/テキスト/連絡先/WiFi対応・動的QR・スキャン履歴・アクセス解析・バッチ生成 (LINE/Amazon競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
