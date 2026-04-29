-- PS#4 S450: 競合3社追加 1171→1174社 (norton/malwarebytes/sophos)
-- SEO: "Norton代替"/"Malwarebytes代替"/"Sophos代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S450: 競合3社追加 1171→1174社 (norton/malwarebytes/sophos)',
  'comparison_page.dartにnorton(Gen Digital コンシューマーセキュリティLifeLock VPN/security/FFCC00)/malwarebytes(マルウェア除去ThreatDown リアルタイム保護/security/0082F5)/sophos(ビジネスセキュリティIntercept X EDR/XDR MDR/enterprise-security/007AC9)の3社追加(1171→1174社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
