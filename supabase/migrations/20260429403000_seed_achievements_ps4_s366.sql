-- PS#4 S366: 競合3社追加 969→972社 (close-crm/apollo-io/agile-crm)
-- SEO: "Close代替"/"Apollo.io代替"/"Agile CRM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S366: 競合3社追加 969→972社 (close-crm/apollo-io/agile-crm)',
  'comparison_page.dartにclose-crm(営業特化CRMコールトラッキングシーケンス/crm/6C47FF)/apollo-io(営業インテリジェンス見込み客DB/crm/0A66C2)/agile-crm(中小企業オールインワンCRM/crm/FF6900)の3社追加(969→972社)。sitemap 1021 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
