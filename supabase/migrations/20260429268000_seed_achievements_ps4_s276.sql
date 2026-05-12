-- PS#4 S276: 競合3社追加 699→702社 (codecademy/kaggle/edx)
-- SEO: "Codecademy代替"/"Kaggle代替"/"edX代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S276: 競合3社追加 699→702社 (codecademy/kaggle/edx)',
  'comparison_page.dartにcodecademy(インタラクティブコーディング学習/coding/1F4056)/kaggle(Googleデータサイエンスコンペ/learning/20BEFF)/edx(MIT/Harvard MOOC/learning/02262B)の3社追加(699→702社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
