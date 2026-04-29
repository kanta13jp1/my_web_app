-- PS#4 S305: 競合3社追加 786→789社 (streamyard/riverside/descript)
-- SEO: "StreamYard代替"/"Riverside代替"/"Descript代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S305: 競合3社追加 786→789社 (streamyard/riverside/descript)',
  'comparison_page.dartにstreamyard(ブラウザベースライブ配信ポッドキャスト/streaming/8B5CF6)/riverside(ポッドキャスト動画インタビュー高品質録画/podcast/0891B2)/descript(AI動画ポッドキャスト編集文字起こし/video-editing/4F46E5)の3社追加(786→789社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
