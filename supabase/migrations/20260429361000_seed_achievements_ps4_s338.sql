-- PS#4 S338: 競合3社追加 885→888社 (together-ai/anyscale/replicate)
-- SEO: "Together AI代替"/"Anyscale代替"/"Replicate代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S338: 競合3社追加 885→888社 (together-ai/anyscale/replicate)',
  'comparison_page.dartにtogether-ai(高速安価OSSモデル推論API/llm-api/7C5CBF)/anyscale(Rayベース分散AILLMサービング/llm-api/028CF7)/replicate(AIモデルAPIマーケットプレイス/llm-api/0E131F)の3社追加(885→888社)。sitemap 931 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
