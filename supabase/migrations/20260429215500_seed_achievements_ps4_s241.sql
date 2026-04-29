-- PS#4 S241: 競合3社追加 594→597社 (cohere/mistral-api/groq)
-- SEO: "Cohere代替"/"Mistral API代替"/"Groq代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S241: 競合3社追加 594→597社 (cohere/mistral-api/groq)',
  'comparison_page.dartにcohere(エンタープライズLLM/RAG/llm-api/39594D)/mistral-api(フランス発高効率LLM/llm-api/FF7000)/groq(LPU超高速推論/llm-api/F54E4E)の3社追加(594→597社)。sitemap 601 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
