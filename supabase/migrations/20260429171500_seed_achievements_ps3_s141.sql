-- PS#3 S141: AI大学 376→378社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S141: WebArena 追加 — 376→377社',
    'WebArena (CMU / Shuyan Zhou et al. / Webナビゲーションベンチマーク / 812タスク / 5実環境:Shopping+CMS+Reddit+Map+Wikipedia / リアルサイト操作評価 / GPT-4~13%→Claude~70% / VisualWebArena/WorkArena派生 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S141: AgentBench 追加 — 377→378社',
    'AgentBench (清華大学 / Xiao Liu et al. / 8環境統合エージェント評価 / OS+DB+KG+HH+WS+WA+M2W+LTP / GPT-4~3.79/10 / オープンソースモデル比較 / コンテキスト長重要性証明 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
