-- PS版#116: ai-hub Phase 8 — deepinfra + liquid (31→33プロバイダー)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ai-hub Phase 8: 33プロバイダー達成 (DeepInfra + Liquid AI追加)',
  'ai-hub Edge Function に DeepInfra (api.deepinfra.com/v1/openai, Llama 3.1 70B) と Liquid AI (api.liquid.ai/v1, LFM-40B) を追加。31→33プロバイダー。',
  '2026-04-18'
)
ON CONFLICT DO NOTHING;
