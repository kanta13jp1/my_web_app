-- PS#4 S442: 競合3社追加 1150→1153社 (front-app/yesware/nimble-crm)
-- SEO: "Front代替"/"Yesware代替"/"Nimble CRM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S442: 競合3社追加 1150→1153社 (front-app/yesware/nimble-crm)',
  'comparison_page.dartにfront-app(共有受信箱チームメールCRM統合SLA管理/customer-support/FA5300)/yesware(Gmail/Outlook営業メール追跡テンプレートSalesforce同期/email-sales/2BAD78)/nimble-crm(ソーシャルCRM SNS統合コンタクト充実化/crm/13A5E7)の3社追加(1150→1153社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
