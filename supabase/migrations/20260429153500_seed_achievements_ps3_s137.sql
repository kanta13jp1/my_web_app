-- PS#3 S137: AI大学 368→370社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S137: AgentVerse 追加 — 368→369社',
    'AgentVerse (OpenBMB / 清華大学NLP Lab / マルチエージェントシミュレーション / 役割ベース協調 / 動的チーム編成 Dynamic Recruitment / Selector+Visibility / ローカルLLM対応 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S137: OpenAgents 追加 — 369→370社',
    'OpenAgents (XLang Lab / Yale-NUS College / Tao Yu / 3エージェント統合: Data+Plugins+Web / ChatGPT Plugin互換 / Web UI / React+FastAPI / Spider Text-to-SQL著者 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
