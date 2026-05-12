-- PS#4 S266: 競合3社追加 669→672社 (teamspirit/jinjer/doda)
-- SEO: "TeamSpirit代替"/"ジンジャー代替"/"doda代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S266: 競合3社追加 669→672社 (teamspirit/jinjer/doda)',
  'comparison_page.dartにteamspirit(日本勤怠/工数/経費管理/hr-jp/00A0E9)/jinjer(日本中小企業HRM/hr-jp/FF6B35)/doda(パーソルキャリア転職/job-board-jp/00ABE6)の3社追加(669→672社)。sitemap 673 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
