-- PS#4 S240: 競合3社追加 591→594社 (openai-api/anthropic-api/google-gemini-api)
-- SEO: "OpenAI API代替"/"Anthropic API代替"/"Google Gemini API代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S240: 競合3社追加 591→594社 (openai-api/anthropic-api/google-gemini-api)',
  'comparison_page.dartにopenai-api(GPT-4/GPT-4o API/llm-api/10A37F)/anthropic-api(Claude 3シリーズAPI/llm-api/CC785C)/google-gemini-api(Gemini マルチモーダルAPI/llm-api/4285F4)の3社追加(591→594社)。sitemap 601 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
