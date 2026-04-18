-- PS版#115: ai-hub Phase 7 — replicate + coze (29→31プロバイダー)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ai-hub Phase 7: 31プロバイダー達成 (Replicate + Coze追加)',
  'ai-hub Edge Function に Replicate (OpenAI-compat openai-compat.replicate.com) と Coze (ByteDance, api.coze.com) を追加。29→31プロバイダー。Rule17: horse-racing-update timeout 20→45分修正。',
  '2026-04-18'
)
ON CONFLICT DO NOTHING;
