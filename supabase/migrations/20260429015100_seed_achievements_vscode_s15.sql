-- VSCode S15: ai-hub EF 自動 quota フォールバック実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'VSCode S15: ai-hub quota自動フォールバック',
  'edge_llm.invoke 明示的 providerId パス: isRetriable=true 時に anthropic→google→openai フォールバックチェーン追加。deno lint/check 0 errors。cross-instance-pr 20260424_ai_hub_quota_fallback クローズ。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
