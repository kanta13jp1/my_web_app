-- PS#4 S89: vs-*ページ canonical URL修正 + /competitors routeMeta追加 + sitemap改善
-- S89a: vsMatch ブロックに setCanonical(window.location.href) 追加
-- S89b: routeMeta に /competitors(174社) /tech-blog-tracker /real-world-danshari 追加
-- S89c: sitemap /competitors priority 0.7→0.9 + /real-world-danshari 追加

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S89: vs-*ページcanonical修正 + /competitors OGP追加 + sitemap改善',
  '全vs-*ページにsetCanonical追加(従来はトップページcanonicalを継承)。routeMetaに/competitorsを初めて登録(174社比較ハブページ)。sitemapで/competitorsをpriority 0.9に昇格。/real-world-danshari をsitemap追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
