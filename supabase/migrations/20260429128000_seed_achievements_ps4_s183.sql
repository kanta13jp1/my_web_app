-- PS#4 S183: 競合3社追加 420→423社 (getresponse/aweber/drip)
-- SEO: "GetResponse代替"/"AWeber代替"/"Drip代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S183: 競合3社追加 420→423社 (getresponse/aweber/drip)',
  'comparison_page.dartにgetresponse(メール+LP+ウェビナー/email/00BAFF)/aweber(パイオニアメール/email/FFA500)/drip(ECメールCRM/email/8B31B4)の3社追加(420→423社)。sitemap 466 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
