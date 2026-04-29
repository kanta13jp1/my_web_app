-- PS#4 S135: 競合3社追加 276→279社 (microsoft-onenote/apple-notes/google-keep)
-- SEO: "OneNote代替"/"Apple Notes代替"/"Google Keep代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S135: 競合3社追加 276→279社 (microsoft-onenote/apple-notes/google-keep)',
  'comparison_page.dartにmicrosoft-onenote(デジタルノート情報整理/notes/7719AA)/apple-notes(Apple専用シンプルノート/notes/FFCC00)/google-keep(Googleメモ付箋/notes/FBBC04)の3社追加(276→279社)。sitemap328URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
