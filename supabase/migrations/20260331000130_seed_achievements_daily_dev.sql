-- daily-development 2026-03-31: past election results UI + CSV copy
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '過去の選挙結果表示機能 (PastElectionResult)',
    'docs/index.ts のGemini APIスキーマにpastElectionResultsフィールドを追加。PastElectionCandidate・PastElectionResultモデルクラスをlocal_election_reality.dartに新設。LocalElectionRealitySnapshotにフィールド統合（後方互換）。election_victory_page.dartに_buildPastElectionResultsSection/_buildPastElectionCardウィジェットを追加し当選/落選をChip色分け表示。flutter analyze 0件維持。',
    '2026-03-31'
  ),
  (
    '未擁立・単騎CSVコピー機能',
    'election_victory_page.dartの地方選挙スケジュールセクションに「未擁立・単騎をCSVコピー」ボタンを追加。isAlertRedまたはisAlertYellowのエントリを投票日順にソートし、投票日/都道府県/自治体/選挙名/候補者数のCSV形式でクリップボードへコピー。戦略立案に活用可能。',
    '2026-03-31'
  ),
  (
    'Gemini APIレスポンスMarkdownブロック除去',
    'docs/index.tsでGemini APIがMarkdownコードブロック形式(```json...```)でJSONを返した場合に正規表現で除去する前処理ロジックを追加。過去の選挙結果プロンプト拡張に合わせてエラー耐性を強化。deno lint 0件維持。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
