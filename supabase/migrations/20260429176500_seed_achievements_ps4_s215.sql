-- PS#4 S215: 競合3社追加 516→519社 (helpjuice/zendesk-guide/confluence-cloud)
-- SEO: "Helpjuice代替"/"Zendesk Guide代替"/"Confluence Cloud代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S215: 競合3社追加 516→519社 (helpjuice/zendesk-guide/confluence-cloud)',
  'comparison_page.dartにhelpjuice(FAQ構築/kb/FFC107)/zendesk-guide(ヘルプセンター/kb/03363D)/confluence-cloud(チームWiki/kb/0052CC)の3社追加(516→519社)。sitemap 562 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
