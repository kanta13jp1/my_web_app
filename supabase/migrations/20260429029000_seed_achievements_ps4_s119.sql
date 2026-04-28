-- PS#4 S119: 競合3社追加 228→231社 (squarespace/bubble/ghost)
-- SEO: "Squarespace代替"/"Bubble代替"/"Ghost代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S119: 競合3社追加 228→231社 (squarespace/bubble/ghost)',
  'comparison_page.dartにsquarespace(デザイン重視ウェブサイトビルダー/website/121212)/bubble(ノーコードウェブアプリ開発/no-code/1A1A8C)/ghost(OSS ブログ・ニュースレター/newsletter/15171A)の3社追加(228→231社)。新カテゴリwebsite追加。competitorMeta/sitemap274URLs/_categoryOf更新。全ファイル社数表記231統一完了。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
