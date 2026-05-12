-- PS#3 S122: AI大学 338→340社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S122: OpenHands (AllHands AI) 追加 — 338→339社',
    'OpenHands (旧OpenDevin / AllHands AI / MIT OSS / GitHub 40k+ / Docker サンドボックス / SWE-bench 50%超 / Claude推奨 / 任意LLM / $0 API実費のみ) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S122: SWE-agent (Princeton大学) 追加 — 339→340社',
    'SWE-agent (Princeton NLP Group / OSS / SWE-bench命名元 / ACI設計 / GitHub Issue自動修正 / Claude推奨 / GitHub 14k+ / 2024年自律AIエンジニアリング基礎論文) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
