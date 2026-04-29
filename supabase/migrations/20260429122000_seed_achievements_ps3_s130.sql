-- PS#3 S130: AI大学 354→356社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S130: GPT-Engineer 追加 — 354→355社',
    'GPT-Engineer (Anton Osika/2023年6月公開/GitHub 50k+ stars/仕様→コード全自動生成/バイブコーディング先駆者/MIT OSS/商用版Lovable) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S130: MetaGPT 追加 — 355→356社',
    'MetaGPT (マルチエージェントフレームワーク/ソフトウェア会社シミュレーション/PM+Architect+Engineer+QA役割分担/40k+ stars/論文発表/CrewAI・AutoGen等に影響) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
