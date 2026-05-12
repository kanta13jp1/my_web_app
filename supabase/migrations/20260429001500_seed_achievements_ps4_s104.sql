-- PS#4 S104: 超高検索ボリューム競合3社追加 (stable-diffusion/dalle/llama) 186→189社
-- SEO: "Stable Diffusion代替"/"DALL-E代替"/"Meta Llama代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S104: 競合3社追加 186→189社 (stable-diffusion/dalle/llama) + ai-image/ai-platform',
  'comparison_page.dartにstable-diffusion(OSSローカル画像生成/GPU必須/無料/ai-image)/dalle(DALL-E3 ChatGPT Plus統合/$20/ai-image)/llama(Meta Llama OSS LLM/ローカルGPU/無料/ai-platform)の3社追加(186→189社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記186→189統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
