-- PS#4 S281: 競合3社追加 714→717社 (highspot/showpad/seismic)
-- SEO: "Highspot代替"/"Showpad代替"/"Seismic代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S281: 競合3社追加 714→717社 (highspot/showpad/seismic)',
  'comparison_page.dartにhighspot(セールスイネーブルメントコンテンツ管理/sales/2DB5AD)/showpad(セールスコンテンツバイヤーエンゲージメント/sales/5033B5)/seismic(エンタープライズセールスイネーブルメント/sales/1483C4)の3社追加(714→717社)。sitemap 760 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
