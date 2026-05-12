-- PS#4 S148: 競合3社追加 315→318社 (bear/tana/nuclino)
-- SEO: "Bear代替"/"Tana代替"/"Nuclino代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S148: 競合3社追加 315→318社 (bear/tana/nuclino)',
  'comparison_page.dartにbear(プレミアムMarkdownノート/notes/F7665B)/tana(スーパータグ知識グラフ/notes/6B4EFF)/nuclino(チームナレッジベース/notes/C5003E)の3社追加(315→318社)。全ファイル318統一。sitemap 614 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
