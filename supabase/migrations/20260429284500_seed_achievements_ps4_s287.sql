-- PS#4 S287: 競合3社追加 732→735社 (successfactors/oracle-hcm/ceridian)
-- SEO: "SAP SuccessFactors代替"/"Oracle HCM代替"/"Ceridian代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S287: 競合3社追加 732→735社 (successfactors/oracle-hcm/ceridian)',
  'comparison_page.dartにsuccessfactors(SAP製エンタープライズHCMクラウド/hcm/009DE0)/oracle-hcm(Oracle統合HCMクラウド/hcm/F80000)/ceridian(Dayforceリアルタイム給与HCM/hcm/0066CC)の3社追加(732→735社)。sitemap 778 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
