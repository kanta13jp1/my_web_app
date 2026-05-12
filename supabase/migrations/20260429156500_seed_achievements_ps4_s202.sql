-- PS#4 S202: 競合3社追加 477→480社 (quickbooks/xero/freshbooks)
-- SEO: "QuickBooks代替"/"Xero代替"/"FreshBooks代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S202: 競合3社追加 477→480社 (quickbooks/xero/freshbooks)',
  'comparison_page.dartにquickbooks(SMB会計/accounting/2CA01C)/xero(クラウド会計/accounting/13B5EA)/freshbooks(フリーランス会計/accounting/FF4B5C)の3社追加(477→480社)。sitemap 523 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
