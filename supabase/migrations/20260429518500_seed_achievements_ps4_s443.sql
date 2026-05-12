-- PS#4 S443: 競合3社追加 1153→1156社 (capsule-crm/spike-email/hiver)
-- SEO: "Capsule CRM代替"/"Spike代替"/"Hiver代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S443: 競合3社追加 1153→1156社 (capsule-crm/spike-email/hiver)',
  'comparison_page.dartにcapsule-crm(中小企業シンプルCRM Sales Pipeline Google/Microsoft統合/crm/5EC5F0)/spike-email(メールをチャット化会話型受信箱ビデオ通話内蔵/email/8B5CF6)/hiver(Gmail共有受信箱SLA衝突回避自動化/customer-support/F5A800)の3社追加(1153→1156社)。sitemap 1246 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
