-- PS#4 S411: 競合3社追加 1057→1060社 (wave-financial/zoho-books/netsuite)
-- SEO: "Wave代替"/"Zoho Books代替"/"NetSuite代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S411: 競合3社追加 1057→1060社 (wave-financial/zoho-books/netsuite)',
  'comparison_page.dartにwave-financial(無料会計請求書給与管理中小企業/accounting/0097B2)/zoho-books(Zohoエコシステム統合クラウド会計税務/accounting/E42527)/netsuite(Oracle ERPクラウド財務CRM統合/erp/00578A)の3社追加(1057→1060社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
