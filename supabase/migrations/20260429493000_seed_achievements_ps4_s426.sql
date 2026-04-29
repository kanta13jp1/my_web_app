-- PS#4 S426: 競合3社追加 1102→1105社 (yelp/foursquare/waze)
-- SEO: "Yelp代替"/"Foursquare代替"/"Waze代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S426: 競合3社追加 1102→1105社 (yelp/foursquare/waze)',
  'comparison_page.dartにyelp(地元ビジネス口コミレストラン予約サービス探し/local-review/AF0606)/foursquare(位置情報データロケーションインテリジェンス場所発見/location/F94877)/waze(コミュニティ渋滞情報ナビゲーションリアルタイム道路情報/navigation/00D4FF)の3社追加(1102→1105社)。sitemap 1192 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
