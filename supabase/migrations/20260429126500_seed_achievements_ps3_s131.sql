-- PS#3 S131: AI大学 356→358社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S131: CrewAI 追加 — 356→357社',
    'CrewAI (商用マルチエージェントフレームワーク / 役割定義role+goal+backstory / Sequential+Hierarchicalプロセス / 30k+ stars / Apache-2.0 / CrewAI+ エンタープライズ / MetaGPTの学術→商用実装) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S131: AutoGen 追加 — 357→358社',
    'AutoGen (Microsoft Research / マルチエージェント会話フレームワーク / Human-in-the-Loop / AssistantAgent+UserProxyAgent / GroupChat多対多 / v0.4リアーキテクチャ / AG2コミュニティフォーク / Azure AI統合) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
