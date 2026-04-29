-- PS#4 S449: 競合3社追加 1171→1174社 (ping-identity/duo-security/bitdefender)
-- SEO: "Ping Identity代替"/"Duo Security代替"/"Bitdefender代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S449: 競合3社追加 1171→1174社 (ping-identity/duo-security/bitdefender)',
  'comparison_page.dartにping-identity(エンタープライズIDセキュリティPingOne SSO/MFA/PAN ハイブリッド/iam/00BFB3)/duo-security(Cisco MFAゼロトラストアクセスデバイストラストVPNレス/mfa/6CC04A)/bitdefender(GravityZone EDR/XDR AI脅威検出/endpoint-security/ED1C24)の3社追加(1171→1174社)。sitemap 1264 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
