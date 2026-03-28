-- Session 2026-03-28 Session 3: fl_chart修正・docs整備・Edge Function改善
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('fl_chart API移行完了', 'SideTitleWidget(axisSide→meta)修正・5ファイル対応、flutter analyze 0エラー維持', '2026-03-28'),
  ('競合21社ドキュメント統一', 'docs/配下の14社・19社表記を全て21社に更新（6ファイルのマイメモ→自分株式会社含む）', '2026-03-28'),
  ('ビジネス計画Section17追加', 'GROWTH_STRATEGY_ROADMAP.mdに8部署の総合ビジネス計画追加（企画/広告/営業/HR/経理/調達/事業計画）', '2026-03-28'),
  ('Edge Function GET対応', 'get-home-dashboard・get-admin-usersのPOST専用制限を解除してGETでも呼び出し可能に', '2026-03-28')
ON CONFLICT DO NOTHING;
