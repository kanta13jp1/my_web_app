-- PS#4 S152: 競合3社追加 327→330社 (fitbit/garmin/insight-timer)
-- SEO: "Fitbit代替"/"Garmin代替"/"Insight Timer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S152: 競合3社追加 327→330社 (fitbit/garmin/insight-timer)',
  'comparison_page.dartにfitbit(Googleフィットネストラッカー/fitness/00B0B9)/garmin(GPSスポーツウォッチ/fitness/007CC3)/insight-timer(世界最大瞑想コミュニティ/health/6B8F71)の3社追加(327→330社)。全ファイル330統一。sitemap 620 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
