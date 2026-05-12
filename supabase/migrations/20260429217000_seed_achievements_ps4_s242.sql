-- PS#4 S242: 競合3社追加 597→600社 (together-ai/replicate/fireworks-ai)
-- SEO: "Together AI代替"/"Replicate代替"/"Fireworks AI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S242: 競合3社追加 597→600社 (together-ai/replicate/fireworks-ai)',
  'comparison_page.dartにtogether-ai(OSS LLMクラウド推論/llm-api/4A6FA5)/replicate(AIモデルAPIマーケット/llm-api/000000)/fireworks-ai(高速低コストLLM推論/llm-api/FF6B35)の3社追加(597→600社)。sitemap 601 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
