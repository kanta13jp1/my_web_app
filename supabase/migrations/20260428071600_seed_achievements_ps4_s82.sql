-- PS#4 S82: _CompetitorInfo 20社追加 + sitemap 97ルート
-- 追加20社: asana/trello/todoist/n8n/zapier/netflix/signal/twilio/snowflake/vanta/
--           progate/schoo/sansan/kincone/synthesia/runway/heygen/devin/hugging-face/replicate
-- 累計: 78社 → 98社 _CompetitorInfo / sitemap 77 → 97 ルート

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S82: comparison_page _CompetitorInfo 98社 + sitemap 97ルート',
  '競合比較ページ(_CompetitorInfo)に20社を追加し98社完結。sitemapも97vs-*ルートに拡張。追加社: asana/trello/todoist/n8n/zapier/netflix/signal/twilio/snowflake/vanta/progate/schoo/sansan/kincone/synthesia/runway/heygen/devin/hugging-face/replicate。残74社(172-98=74)を次回バッチで追加予定。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
