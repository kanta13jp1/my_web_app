-- PS#3 S125: AI大学 344→346社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S125: Qodo (旧CodiumAI) 追加 — 344→345社',
    'Qodo (旧CodiumAI / AIテスト生成 / PR-Agent OSS / コードレビュー / Qodo Gen・Merge・Cover / $19/月 Teams / MIT OSS / GitHub 20k+ stars / VS Code+JetBrains) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S125: CodeRabbit 追加 — 345→346社',
    'CodeRabbit (AI自動PRレビューSaaS / LLM行単位コードレビュー / OSS無料 / $12/月 Lite / GitHub Actions統合 / @coderabbitai対話 / Redis・MinIO採用実績 / PR時間60〜80%削減) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
