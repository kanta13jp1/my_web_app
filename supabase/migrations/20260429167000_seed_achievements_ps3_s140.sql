-- PS#3 S140: AI大学 374→376社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S140: CAMEL 追加 — 374→375社',
    'CAMEL (KAUST / King Abdullah University / 役割演技型マルチエージェント / Inception Prompting / AI_User+AI_Assistant対話 / 2,500対話データセット / ChatDev+MetaGPT+CrewAIへの影響 / camel-ai/camel OSS / Apache-2.0) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S140: SWE-bench 追加 — 375→376社',
    'SWE-bench (Princeton/CMU / Carlos Jimenez et al. / GitHub Issue解決ベンチマーク / AI開発能力標準評価 / 2294タスク / 12 OSS repos / Verified/Lite派生 / Devin13%→Claude~49%→Devin2.0~53% / LiveSWE-bench / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
