-- PS#4 S218: 競合3社追加 525→528社 (qualtrics/survio/alchemer)
-- SEO: "Qualtrics代替"/"Survio代替"/"Alchemer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S218: 競合3社追加 525→528社 (qualtrics/survio/alchemer)',
  'comparison_page.dartにqualtrics(エンタープライズXM/survey/1A1A2E)/survio(オンラインアンケート/survey/00BFA5)/alchemer(フレキシブルサーベイ/survey/1E88E5)の3社追加(525→528社)。sitemap 571 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
