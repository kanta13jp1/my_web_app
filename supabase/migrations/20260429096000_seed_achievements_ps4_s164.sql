-- PS#4 S164: 競合3社追加 363→366社 (superhuman/planoly/flomo)
-- SEO: "Superhuman代替"/"Planoly代替"/"flomo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S164: 競合3社追加 363→366社 (superhuman/planoly/flomo)',
  'comparison_page.dartにsuperhuman(最速メール/email/E44C65)/planoly(Instagram自動投稿/social/FF5A5F)/flomo(軽量メモ/notes/00B96B)の3社追加(363→366社)。sitemap 409 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
