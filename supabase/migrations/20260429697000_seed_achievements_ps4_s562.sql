-- PS#4 S562: 競合3社追加 継続 (azure-ad/duo/one-identity)
-- SEO: "Microsoft Entra代替"/"Duo Security代替"/"One Identity代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S562: 競合3社追加 (azure-ad/duo/one-identity)',
  'comparison_page.dartにazure-ad(Microsoft Entra ID・SSO・MFA・条件付きアクセス・ゼロトラスト/0078D4)/duo(Cisco MFA・ゼロトラストアクセス・デバイストラスト・VPNレス/6DBE45)/one-identity(IAM/IGA/PAM統合・One Identity Manager・クラウド対応/1C3E6B)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
