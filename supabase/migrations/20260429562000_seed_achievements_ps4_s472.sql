-- PS#4 S472: 競合3社追加 1237→1240社 (skyscanner/citymapper/here-maps)
-- SEO: "Skyscanner代替"/"Citymapper代替"/"HERE Maps代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S472: 競合3社追加 1237→1240社 (skyscanner/citymapper/here-maps)',
  'comparison_page.dartにskyscanner(フライト比較最安値アラート柔軟日程/0770E3)/citymapper(都市交通リアルタイム遅延シェアモビリティ/00C852)/here-maps(高精度地図オフラインEV自動車OEM統合/00AFAA)の3社追加(1237→1240社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
