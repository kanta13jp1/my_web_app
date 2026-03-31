-- VSCode Session 2026-04-01: 孤立ページ全接続・ユーザーマニュアル更新・EdgeFunctionSummaryCard 115本対応
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '孤立ページ全接続 — 14ページのルート+カタログを追加',
    'main.dartに /ai-status /asset-management /cfo-office /cho-office /chro-office /cmo-office /cmo /election-strategy /mind-map /mindless-task /real-world-danshari /stock-tasks /wardrobe の13ルートを追加。home_tool_catalog.dartにCmoPage(プレスリリース生成)とAssetManagementPage(資産管理)のカタログエントリを追加。election_management_dashboard.dart(lint エラー発生源)を削除。',
    '2026-04-01'
  ),
  (
    'ユーザーマニュアル全更新 — 全旧セクション名を現行UIに修正',
    'user_manual_page.dartの全staleセクション名を修正: CEO OFFICE→QUICK ACCESS今日の運用、CMO/CKO OFFICE→知識・意思決定、CSO OFFICE→知識・意思決定、GROWTH/成長導線→成長・発信。新規接続ページ13件の操作手順を追記: 思考停止ログ・週末ストック・市場分析(CMO)・マインドマップ・健康管理(CHO)・人事厚生(CHRO)・資産管理・ワードローブ整理・断捨離(リアル)・AI稼働モニター・プレスリリース生成(CMO)・2026衆院選勝利戦略室。',
    '2026-04-01'
  ),
  (
    'EdgeFunctionSummaryCard を 115本体制に更新',
    'lib/widgets/edge_function_summary_card.dartのEdge Function一覧を115本に同期。api-key-manager・cohort-analysis・document-collaboration・email-service・integration-connector・leave-management・marketplace・payment-processor・performance-review・scheduled-notifications・video-audio-manager・wiki-databaseの12関数を追加。',
    '2026-04-01'
  )
ON CONFLICT DO NOTHING;
