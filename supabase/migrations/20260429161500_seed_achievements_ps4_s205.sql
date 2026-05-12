-- PS#4 S205: 競合3社追加 486→489社 (deepl/weglot/lokalise)
-- SEO: "DeepL代替"/"Weglot代替"/"Lokalise代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S205: 競合3社追加 486→489社 (deepl/weglot/lokalise)',
  'comparison_page.dartにdeepl(ニューラル翻訳/translation/0F2B46)/weglot(Web多言語化/localization/2BD4C7)/lokalise(ローカライゼーション管理/localization/FF4D70)の3社追加(486→489社)。sitemap 535 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
