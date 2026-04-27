-- PS#4 S86: _CompetitorInfo 最終完結バッチ (17社追加) + sitemap 174ルート
-- 追加17社: jules-google/kore-ai/lifenet-insurance/magic-ai/metamask/money-tree/
--           paidy/pipedream/poshmark/roblox/sagawa-express/toyota-connected/
--           ubereats-japan/xbox-cloud-gaming/yamato-transport/sakura-internet/viz-ai
-- 累計: 158社 → 174社 _CompetitorInfo / sitemap 157 → 174 ルート (完結)

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S86: comparison_page _CompetitorInfo 174社完結 + sitemap 174ルート',
  '競合比較ページ(_CompetitorInfo)に最終17社を追加し174社完結。sitemapも174vs-*ルートに拡張。追加社: jules-google/kore-ai/lifenet-insurance/magic-ai/metamask/money-tree/paidy/pipedream/poshmark/roblox/sagawa-express/toyota-connected/ubereats-japan/xbox-cloud-gaming/yamato-transport/sakura-internet/viz-ai。PS#4全社完結達成。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
