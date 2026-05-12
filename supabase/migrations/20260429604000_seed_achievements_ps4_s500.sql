-- PS#4 S500: 競合3社追加 継続 (polar-flow/trainingpeaks/wahoo) 🎉500マイルストーン
-- SEO: "Polar Flow代替"/"TrainingPeaks代替"/"Wahoo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S500: 🎉500マイルストーン 競合3社追加 (polar-flow/trainingpeaks/wahoo)',
  'comparison_page.dartにpolar-flow(Training Load Pro Nightly Recharge心拍ゾーンGPS/D50000)/trainingpeaks(TSS/CTL/ATLコーチ連携ゴール設定パワー分析持久力特化/1B5E20)/wahoo(KickrスマートトレーナーSYSTM AIトレーニングパワー計測/E53935)の3社追加。sitemap 1417 vs-URLs。PS#4 500セッション達成！',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
