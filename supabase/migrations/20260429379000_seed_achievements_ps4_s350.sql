-- PS#4 S350: 競合3社追加 921→924社 (endel/cleanvoice/auphonic)
-- SEO: "Endel代替"/"Cleanvoice代替"/"Auphonic代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S350: 競合3社追加 921→924社 (endel/cleanvoice/auphonic)',
  'comparison_page.dartにendel(AIパーソナライズ環境音集中睡眠リラックス/wellness/1E3A5F)/cleanvoice(AIポッドキャスト音声ノイズ除去クリーニング/audio-tools/0F172A)/auphonic(AI音声後処理ラウドネス正規化/audio-tools/0369A1)の3社追加(921→924社)。sitemap 967 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
