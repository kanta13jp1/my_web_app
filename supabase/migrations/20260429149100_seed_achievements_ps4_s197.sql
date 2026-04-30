-- PS#4 S197: 競合3社追加 462→465社 (okta/auth0/jumpcloud)
-- SEO: "Okta代替"/"Auth0代替"/"JumpCloud代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S197: 競合3社追加 462→465社 (okta/auth0/jumpcloud)',
  'comparison_page.dartにokta(SSO+ID管理/security/007DC1)/auth0(開発者認証/security/EB5424)/jumpcloud(クラウドディレクトリ/security/00A4E4)の3社追加(462→465社)。sitemap 508 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
