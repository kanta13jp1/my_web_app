-- PS#4 S209: 競合3社追加 498→501社 (basecamp/wrike/smartsheet)
-- SEO: "Basecamp代替"/"Wrike代替"/"Smartsheet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S209: 競合3社追加 498→501社 (basecamp/wrike/smartsheet)',
  'comparison_page.dartにbasecamp(シンプルPM/pm/1D2D35)/wrike(エンタープライズPM/pm/0C9E5A)/smartsheet(スプレッドシートPM/pm/0C7C59)の3社追加(498→501社)。sitemap 544 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
