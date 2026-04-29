-- PS#4 S583: 競合3社追加 継続 (amazon-quicksight/google-looker-studio/mode)
-- SEO: "Amazon QuickSight代替"/"Google Looker Studio代替"/"Mode代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S583: 競合3社追加 (amazon-quicksight/google-looker-studio/mode)',
  'comparison_page.dartにamazon-quicksight(クラウドBI・SPICE・機械学習インサイト・AWSネイティブ/FF9900)/google-looker-studio(無料BI・Google Analytics/Ads統合・クラウドネイティブ/4285F4)/mode(SQLベースBI・Python/R統合・データアナリスト/6E2FFA)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
