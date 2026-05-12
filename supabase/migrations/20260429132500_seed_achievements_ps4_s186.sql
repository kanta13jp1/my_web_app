-- PS#4 S186: 競合3社追加 429→432社 (crazy-egg/mouseflow/logrocket)
-- SEO: "Crazy Egg代替"/"Mouseflow代替"/"LogRocket代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S186: 競合3社追加 429→432社 (crazy-egg/mouseflow/logrocket)',
  'comparison_page.dartにcrazy-egg(ヒートマップA/B/web-analytics/FF4136)/mouseflow(セッション録画/web-analytics/FFAB40)/logrocket(フロントエンド監視/web-analytics/764BC2)の3社追加(429→432社)。sitemap 475 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
