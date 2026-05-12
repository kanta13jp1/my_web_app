-- PS#4 S400: 競合3社追加 1024→1027社 (grain/lemlist/instantly)
-- SEO: "Grain代替"/"lemlist代替"/"Instantly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S400: 競合3社追加 1024→1027社 (grain/lemlist/instantly)',
  'comparison_page.dartにgrain(ビデオ通話自動記録AI要約セールスコーチング/meeting-intelligence/6C3CD1)/lemlist(パーソナライズコールドメールマルチチャネルセールス/sales-engagement/4BADE8)/instantly(大量コールドメール送信ウォームアップデリバラビリティ/sales-engagement/6366F1)の3社追加(1024→1027社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
