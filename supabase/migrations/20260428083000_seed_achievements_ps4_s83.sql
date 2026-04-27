-- PS#4 S83: _CompetitorInfo 20社追加 + sitemap 117ルート
-- 追加20社: niconico/nintendo/ntt-docomo/softbank-telecom/tabelog/suumo/threads/tiktok-shop/
--           hatena/yayoi/you-com/mem-ai/together-ai/postman/sentry/pika/wise/oura/coincheck/perplexity-ai
-- 累計: 98社 → 118社 _CompetitorInfo / sitemap 97 → 117 ルート

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S83: comparison_page _CompetitorInfo 118社 + sitemap 117ルート',
  '競合比較ページ(_CompetitorInfo)に20社を追加し118社完結。sitemapも117vs-*ルートに拡張。追加社: niconico/nintendo/ntt-docomo/softbank-telecom/tabelog/suumo/threads/tiktok-shop/hatena/yayoi/you-com/mem-ai/together-ai/postman/sentry/pika/wise/oura/coincheck/perplexity-ai。残54社(172-118=54)を次回バッチで追加予定。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
