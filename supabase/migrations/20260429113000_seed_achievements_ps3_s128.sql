-- PS#3 S128: AI大学 350→352社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S128: AutoCodeRover 追加 — 350→351社',
    'AutoCodeRover (NUS+Alibaba DAMO Academy共同開発 / AST+セマンティック検索でコンテキスト圧縮 / SWE-bench Verified ~52% / ACR-2 / Apache-2.0 OSS / 学術系最高水準 / LLM自律バグ修正) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S128: Agentless 追加 — 351→352社',
    'Agentless (UIUC開発 / エージェントレス設計哲学 / 3フェーズパイプライン=Localization+Repair+Validation / SWE-bench Full ~30% / $0.34/issue / KISSアーキテクチャ / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
