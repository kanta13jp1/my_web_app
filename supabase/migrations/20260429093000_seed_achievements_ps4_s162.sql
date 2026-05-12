-- PS#4 S162: 競合3社追加 357→360社 (sleep-cycle/ynab/monarch-money)
-- SEO: "Sleep Cycle代替"/"YNAB代替"/"Monarch Money代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S162: 競合3社追加 357→360社 (sleep-cycle/ynab/monarch-money)',
  'comparison_page.dartにsleep-cycle(スマートアラーム/sleep/7B68EE)/ynab(ゼロベース予算/finance/84BD41)/monarch-money(資産・投資管理/finance/00B894)の3社追加(357→360社)。sitemap 403 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
