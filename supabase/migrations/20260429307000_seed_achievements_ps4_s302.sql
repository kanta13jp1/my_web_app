-- PS#4 S302: 競合3社追加 777→780社 (affise/8x8/cloudtalk)
-- SEO: "Affise代替"/"8x8代替"/"CloudTalk代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S302: 競合3社追加 777→780社 (affise/8x8/cloudtalk)',
  'comparison_page.dartにaffise(パフォーマンスマーケアフィリエイト追跡/affiliate/1E40AF)/8x8(UCaaSコンタクトセンター統合/voip/FF6B35)/cloudtalk(スマートビジネス電話コールセンター/voip/00D2FF)の3社追加(777→780社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
