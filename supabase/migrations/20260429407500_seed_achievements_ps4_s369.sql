-- PS#4 S369: 競合3社追加 978→981社 (sage/clio/booksy)
-- SEO: "Sage代替"/"Clio代替"/"Booksy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S369: 競合3社追加 978→981社 (sage/clio/booksy)',
  'comparison_page.dartにsage(中小企業会計在庫給与ERP/accounting/00DC82)/clio(法律事務所ケース管理請求/legal/004BFF)/booksy(美容ウェルネス予約管理/booking/6D00CC)の3社追加(978→981社)。sitemap 1030 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
