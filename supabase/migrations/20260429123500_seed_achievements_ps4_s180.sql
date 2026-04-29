-- PS#4 S180: 競合3社追加 411→414社 (tally/paperform/formstack)
-- SEO: "Tally代替"/"Paperform代替"/"Formstack代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S180: 競合3社追加 411→414社 (tally/paperform/formstack)',
  'comparison_page.dartにtally(Typeform代替無料フォーム/form/FF6B6B)/paperform(スマートフォーム/form/4A90D9)/formstack(エンタープライズフォーム/form/F15A29)の3社追加(411→414社)。sitemap 457 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
