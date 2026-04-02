-- Session 432c (Web版): Edge Functions 120→125 (5本追加)
-- inventory-manager, order-tracker, ci-cd-pipeline, compensation-manager, financial-report

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('在庫・資産管理機能', 'Amazon/MoneyForward競合の物品・デジタル資産登録・入出庫管理・在庫アラート・カテゴリ管理を実装', '2026-03-31'),
  ('注文・配送追跡機能', 'Amazon競合の注文登録・配送ステータス追跡・注文履歴・ウィッシュリスト管理を実装', '2026-03-31'),
  ('CI/CDパイプライン管理', 'GitHub Actions/Claude Code競合のパイプライン設定・ビルド記録・デプロイ統計・ロールバック管理を実装', '2026-03-31'),
  ('給与・報酬管理機能', 'ジョブカン/MoneyForward競合の給与計算・賞与管理・給与明細履歴・年次統計を実装', '2026-03-31'),
  ('財務レポート機能', 'MoneyForward/Microsoft競合の損益計算書(P/L)・キャッシュフロー分析・カテゴリ別支出分析・年次比較を実装', '2026-03-31')
ON CONFLICT DO NOTHING;
