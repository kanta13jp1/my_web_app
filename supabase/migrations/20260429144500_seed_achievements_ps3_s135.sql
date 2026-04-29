-- PS#3 S135: AI大学 364→366社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S135: TaskWeaver 追加 — 364→365社',
    'TaskWeaver (Microsoft Research / コードファーストAIエージェント / Python実行単位 / Planner+CodeInterpreter 2コンポーネント / Plugin YAML定義 / データ分析特化 / Azure OpenAI統合 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S135: Smol Developer 追加 — 365→366社',
    'Smol Developer (smol AI / swyx / 200行以下のAIエンジニア / バイブコーディング原点 / 2023年5月公開 / 全ファイル一括生成 / 最小主義哲学 / GPT-4活用 / MIT OSS / 後のGPT-Engineer・Devin・Cursorに影響) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
