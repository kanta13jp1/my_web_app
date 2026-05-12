-- PS#4 S413: 競合3社追加 1063→1066社 (pleo/spendesk/bench-co)
-- SEO: "Pleo代替"/"Spendesk代替"/"Bench代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S413: 競合3社追加 1063→1066社 (pleo/spendesk/bench-co)',
  'comparison_page.dartにpleo(企業カード経費管理請求書自動処理ヨーロッパ向け/expense/00D4AA)/spendesk(企業支出管理仮想カード請求書予算管理/expense/6200EA)/bench-co(スモールビジネス向け月次ブックキーピング代行/bookkeeping/1E4D3B)の3社追加(1063→1066社)。sitemap 1156 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
