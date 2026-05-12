-- PS#4 S448: 競合3社追加 1168→1171社 (sentinelone/cyberark/onelogin)
-- SEO: "SentinelOne代替"/"CyberArk代替"/"OneLogin代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S448: 競合3社追加 1168→1171社 (sentinelone/cyberark/onelogin)',
  'comparison_page.dartにsentinelone(AI駆動EPP/EDR/XDR自律応答Singularity Platform Purple AI/endpoint-security/6700FF)/cyberark(PAM特権アクセス管理シークレット管理ゼロトラスト/iam/0078D4)/onelogin(クラウドIDaaS SSO MFAアクセス管理HR統合/iam/00A1E0)の3社追加(1168→1171社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
