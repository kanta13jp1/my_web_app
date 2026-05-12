-- PS#4 S612: 競合3社追加 継続 (chef/cloudformation/bicep)
-- SEO: "Chef代替"/"AWS CloudFormation代替"/"Azure Bicep代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S612: 競合3社追加 (chef/cloudformation/bicep)',
  'comparison_page.dartにchef(構成管理・Ruby DSL・IaC・コンプライアンス自動化/F09820)/cloudformation(AWS IaC・スタック管理・ドリフト検出・SAM/FF9900)/bicep(Azure IaC・ARM代替・宣言型・型安全/0078D4)の3社追加(1663社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
