-- PS#4 S172: 競合3社追加 387→390社 (keeper/dashlane/nordpass)
-- SEO: "Keeper代替"/"Dashlane代替"/"NordPass代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S172: 競合3社追加 387→390社 (keeper/dashlane/nordpass)',
  'comparison_page.dartにkeeper(ゼロ知識PW管理/security/0070F3)/dashlane(VPN内蔵PW管理/security/006CFF)/nordpass(XChaCha20/security/4687FF)の3社追加(387→390社)。sitemap 433 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
