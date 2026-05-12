-- PS#4 S201: 競合3社追加 474→477社 (backlog/kintone/eight)
-- SEO: "Backlog代替"/"kintone代替"/"Eight代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S201: 競合3社追加 474→477社 (backlog/kintone/eight)',
  'comparison_page.dartにbacklog(日本語PM/pm/54C5C6)/kintone(サイボウズノーコード/nocode-jp/E03E2D)/eight(名刺管理/contact/FF7043)の3社追加(474→477社)。sitemap 520 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
