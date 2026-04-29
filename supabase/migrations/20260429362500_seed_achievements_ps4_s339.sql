-- PS#4 S339: 競合3社追加 888→891社 (deepinfra/lepton-ai/mistral-ai)
-- SEO: "DeepInfra代替"/"Lepton AI代替"/"Mistral AI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S339: 競合3社追加 888→891社 (deepinfra/lepton-ai/mistral-ai)',
  'comparison_page.dartにdeepinfra(高速安価LLM Diffusion推論API/llm-api/6366F1)/lepton-ai(AIクラウドLLMサービングインフラ/gpu-cloud/0EA5E9)/mistral-ai(ヨーロッパ発OSS LLM高効率API/llm-api/FF7000)の3社追加(888→891社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
