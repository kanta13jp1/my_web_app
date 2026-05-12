-- PS#4 S113: 超高検索ボリューム競合3社追加 (flux/kling/activecampaign) 210→213社
-- SEO: "FLUX代替"/"Kling AI代替"/"ActiveCampaign代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S113: 競合3社追加 210→213社 (flux/kling/activecampaign)',
  'comparison_page.dartにflux(FLUX AI画像生成/Black Forest Labs/API従量/ai-image)/kling(Kling AI高品質動画生成/Kuaishou/月額約10USD/ai-video)/activecampaign(メール自動化CRM統合/月額15USD~/email-marketing)の3社追加(210→213社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記210→213統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
