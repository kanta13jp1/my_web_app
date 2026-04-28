-- PS#4 S112: 超高検索ボリューム競合3社追加 (substack/klaviyo/remove-bg) 207→210社
-- SEO: "Substack代替"/"Klaviyo代替"/"remove.bg代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S112: 競合3社追加 207→210社 (substack/klaviyo/remove-bg)',
  'comparison_page.dartにsubstack(ニュースレター配信・クリエイター収益化/手数料10%/newsletter)/klaviyo(ECメール/SMS自動化/月額20USD~/email-marketing)/remove-bg(AI背景除去/無料~月額9USD/photo-ai)の3社追加(207→210社)。新カテゴリnewsletter追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記207→210統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
