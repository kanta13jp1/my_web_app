-- PowerShell 全体管理セッション #3 実績シード 2026-03-31

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'EmbeddingLab Gemini類似度比較機能実装',
    'embedding_lab_page.dartをgemini-embedding-001を使ったコサイン類似度比較ツールに全面刷新。2テキストを並列Embedding取得→コサイン類似度計算→LinearProgressIndicator+カラーラベル(緑/オレンジ/赤)でスコア可視化。セマンティックノート検索の実験基盤として整備。flutter analyze 0件維持。',
    '2026-03-31'
  ),
  (
    'LocalElectionRealityモデル・スナップショット履歴管理サービス追加',
    'local_election_reality.dartモデルとlocal_election_reality_service.dartサービスを新規追加。国民民主党の議員数スナップショットを180日分の日次履歴としてshared_preferencesで管理し、LineChartで時系列可視化する基盤を整備。テストも追加。',
    '2026-03-31'
  ),
  (
    'flutter analyze 0件維持 (Lint修正 num→double・unused import・trailing comma)',
    'election_victory_page.dartのnum→double型不一致修正(argument_type_not_assignable)・home_tool_catalog.dartの未使用import削除・local_election_reality_service.dartのtrailing comma修正。4インスタンス並列開発での競合なし統合を実現。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
