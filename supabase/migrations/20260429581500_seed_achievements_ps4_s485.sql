-- PS#4 S485: 競合3社追加 1278社継続 (pillow/rise-science/replika)
-- SEO: "Pillow代替"/"Rise Science代替"/"Replika代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S485: 競合3社追加 (pillow/rise-science/replika)',
  'comparison_page.dartにpillow(AI睡眠分析Apple Watch連携音声録音スマートアラーム睡眠スコア/5B5EA6)/rise-science(睡眠負債計測エネルギーグラフPeak HoursSleep CoachCircadian科学/FF6B35)/replika(AIコンパニオン感情サポート3DアバターProメンタルウェルネス日記/5B4FE0)の3社追加。sitemap 1372 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
