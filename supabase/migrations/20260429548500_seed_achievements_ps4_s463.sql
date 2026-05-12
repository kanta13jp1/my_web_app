-- PS#4 S463: 競合3社追加 1210→1213社 (samsung-health/google-fit/withings)
-- SEO: "Samsung Health代替"/"Google Fit代替"/"Withings代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S463: 競合3社追加 1210→1213社 (samsung-health/google-fit/withings)',
  'comparison_page.dartにsamsung-health(Galaxy Watch連携歩数/睡眠/心拍ストレス/1428A0)/google-fit(Heart Points Wear OS WHO基準/4285F4)/withings(スマートヘルスデバイス体組成計睡眠マット血圧計/00B5E2)の3社追加(1210→1213社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
