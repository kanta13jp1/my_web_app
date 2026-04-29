-- PS#4 S483: 競合3社追加 1270→1278社 (inshot/snapseed/google-photos)
-- SEO: "InShot代替"/"Snapseed代替"/"Google Photos代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S483: 競合3社追加 1270→1278社 (inshot/snapseed/google-photos)',
  'comparison_page.dartにinshot(モバイル動画編集SNS最適化BGMフィルターテキスト縦横比変換/00C4CC)/snapseed(Google製無料写真編集29ツール非破壊編集SELECTIVEフィルターRAW対応/52B5F7)/google-photos(Google写真バックアップAI整理顔認識メモリーGoogleレンズPixel限定無制限/4285F4)の3社追加(1270→1278社)。sitemap 1372 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
