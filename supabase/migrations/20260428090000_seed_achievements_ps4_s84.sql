-- PS#4 S84: _CompetitorInfo 20社追加 + sitemap 137ルート
-- 追加20社: ameba/bluesky/calendly/carely/cybozu-kintone/datadog/docusign/epic-games/
--           google-ads/harvey-ai/hrmos/hubspot-crm/ikyu/jalan/kddi-au/
--           langchain-inc/luup-micromobility/meta-ads/nvidia-geforce-now/sony-playstation
-- 累計: 118社 → 138社 _CompetitorInfo / sitemap 117 → 137 ルート

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S84: comparison_page _CompetitorInfo 138社 + sitemap 137ルート',
  '競合比較ページ(_CompetitorInfo)に20社を追加し138社完結。sitemapも137vs-*ルートに拡張。追加社: ameba/bluesky/calendly/carely/cybozu-kintone/datadog/docusign/epic-games/google-ads/harvey-ai/hrmos/hubspot-crm/ikyu/jalan/kddi-au/langchain-inc/luup-micromobility/meta-ads/nvidia-geforce-now/sony-playstation。残34社(172-138=34)を次回バッチで追加予定。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
