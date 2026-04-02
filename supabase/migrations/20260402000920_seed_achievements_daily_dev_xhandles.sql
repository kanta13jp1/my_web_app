-- Session daily-development 2026-04-02: 候補者Xハンドル統合・バイラル動画パイプライン・選挙ダッシュボード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '候補者Xハンドル表示 (ActionChip)',
    '選挙スケジュールカードに候補者のXハンドルをActionChipとして表示し、タップでx.com/handleを開く。LocalElectionScheduleEntryにkokuminCandidateXHandlesフィールドを追加。CSVエクスポートに候補者名・Xハンドル列を追加。',
    '2026-04-02'
  ),
  (
    'deno lint 0件 — 12エラー一括修正',
    '240ファイルのEdge Function群でno-unused-vars(9件)/prefer-const(2件)/no-explicit-any(1件)を修正。viral-video-generator/edge-function-test-runnerを含む12ファイルのlintエラーをゼロに。',
    '2026-04-02'
  ),
  (
    'バイラル動画生成パイプライン基盤',
    'viral-video-generator Edge Function新規作成。_shared/edge.ts・_shared/viral-growth.ts・_shared/x-client.tsの共有ユーティリティを整備。config.toml・deploy-prod.ymlにTier2として追加。',
    '2026-04-02'
  ),
  (
    '選挙管理ダッシュボード ルート追加',
    'ElectionManagementDashboardを/election-dashboardルートとしてmain.dartに追加。home_tool_catalogのspecialセクションにエントリを追加し業務メニューから直接アクセス可能に。',
    '2026-04-02'
  ),
  (
    'local-election-intelligence 手動補完データ機能',
    'ManualScheduleSupplementインターフェースを追加し候補者XハンドルをEdge Functionレベルで補完可能に。OfficialScheduledCandidateにxHandleフィールドを追加。',
    '2026-04-02'
  )
ON CONFLICT DO NOTHING;
