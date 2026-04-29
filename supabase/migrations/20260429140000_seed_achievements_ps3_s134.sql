-- PS#3 S134: AI大学 362→364社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S134: LlamaIndex 追加 — 362→363社',
    'LlamaIndex (旧GPT Index / LLM向けデータフレームワーク / Load+Index+Store+Query+Evaluate 5ステップ / 160+ DataConnector / LlamaHub / 35k+ stars / MIT OSS / LlamaIndex Cloud) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S134: DSPy 追加 — 363→364社',
    'DSPy (Stanford University / Omar Khattab / 宣言的LLMプログラミング / 自動プロンプト最適化 / Signature+Module+Optimizer / BootstrapFewShot / MIPRO / モデル非依存 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
