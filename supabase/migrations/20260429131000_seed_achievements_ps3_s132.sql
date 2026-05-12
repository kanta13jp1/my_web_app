-- PS#3 S132: AI大学 358→360社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S132: LangGraph 追加 — 358→359社',
    'LangGraph (LangChainチーム / ステートフルマルチエージェント / グラフ型ワークフロー / サイクルループ / TypedDict状態管理 / Checkpointing / Human-in-the-Loop / LangGraph Studio / LangSmith統合) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S132: ChatDev 追加 — 359→360社',
    'ChatDev (清華大学 / ソフトウェア会社完全シミュレーション / Chat-Chain設計 / CEO+CPO+CTO+Programmer+Tester役割 / Self-Reflection / 25k+ stars / ICML論文 / チャット唯一コミュニケーション) を AI大学コンテンツとして追加。AI大学 360社達成。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
