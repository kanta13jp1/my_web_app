-- PS#4 S85: _CompetitorInfo 20社追加 + sitemap 157ルート
-- 追加20社: anytype/calm/cerebras-systems/cohere/craft-docs/criteo/curon/descript/
--           digi-smac/drata/ecforce/factory-ai/freee-insurance/go-taxi/graffer/
--           itandi/kingoftime/klarna-ai/stores-jp/zoho-crm
-- 累計: 138社 → 158社 _CompetitorInfo / sitemap 137 → 157 ルート

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S85: comparison_page _CompetitorInfo 158社 + sitemap 157ルート',
  '競合比較ページ(_CompetitorInfo)に20社を追加し158社完結。sitemapも157vs-*ルートに拡張。追加社: anytype/calm/cerebras-systems/cohere/craft-docs/criteo/curon/descript/digi-smac/drata/ecforce/factory-ai/freee-insurance/go-taxi/graffer/itandi/kingoftime/klarna-ai/stores-jp/zoho-crm。残14社(172-158=14)を次回最終バッチで追加予定。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
