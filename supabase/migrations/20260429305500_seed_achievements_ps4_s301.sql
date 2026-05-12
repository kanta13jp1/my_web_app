-- PS#4 S301: 競合3社追加 774→777社 (flourish/venngage/mavrck)
-- SEO: "Flourish代替"/"Venngage代替"/"Mavrck代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S301: 競合3社追加 774→777社 (flourish/venngage/mavrck)',
  'comparison_page.dartにflourish(ノーコードインタラクティブデータストーリーテリング/dataviz/E84C89)/venngage(インフォグラフィックレポートプレゼン/infographic/45B649)/mavrck(エンタープライズインフルエンサーマーケ/influencer/6B21A8)の3社追加(774→777社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
