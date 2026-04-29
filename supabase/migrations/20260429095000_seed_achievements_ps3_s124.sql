-- PS#3 S124: AI大学 342→344社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S124: Sourcegraph Cody 追加 — 342→343社',
    'Sourcegraph Cody (コードベース全体理解 / BM25+ベクトル検索ハイブリッド / Claude/GPT-4o対応 / VS Code+JetBrains / $9/月 Pro / OSS / カスタムコマンド / 大規模リポジトリ最強) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S124: Amazon Q Developer 追加 — 343→344社',
    'Amazon Q Developer (旧CodeWhisperer / AWS製 / AWS統合最強 / 補完無制限無料 / /dev・/transform・/review / CloudFormation CDK / セキュリティスキャン / $19/月 Pro / SOC2/GDPR) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
