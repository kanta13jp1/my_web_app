-- PS#4 S140: 競合3社追加 291→294社 (spline/google-forms/surveymonkey)
-- SEO: "Spline代替"/"Google Forms代替"/"SurveyMonkey代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S140: 競合3社追加 291→294社 (spline/google-forms/surveymonkey)',
  'comparison_page.dartにspline(ブラウザベースリアルタイム3Dデザイン/3d/0D6EFD)/google-forms(Googleアンケートフォーム/forms/7248B9)/surveymonkey(オンラインアンケート市場調査/forms/00BF6F)の3社追加(291→294社)。新カテゴリforms追加。全ファイル294統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
