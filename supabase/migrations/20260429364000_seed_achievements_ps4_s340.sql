-- PS#4 S340: 競合3社追加 891→894社 (ai21/stability-ai/runway-ml)
-- SEO: "AI21代替"/"Stability AI代替"/"Runway代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S340: 競合3社追加 891→894社 (ai21/stability-ai/runway-ml)',
  'comparison_page.dartにai21(JambaエンタープライズLLM RAG特化/llm-api/2D3748)/stability-ai(Stable DiffusionOSS画像生成先駆け/image-gen/1A1A2E)/runway-ml(AI動画生成Gen-3映像ツール/video-gen/0F172A)の3社追加(891→894社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
