-- PS#4 S249: 競合3社追加 618→621社 (nordvpn/expressvpn/protonvpn)
-- SEO: "NordVPN代替"/"ExpressVPN代替"/"Proton VPN代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S249: 競合3社追加 618→621社 (nordvpn/expressvpn/protonvpn)',
  'comparison_page.dartにnordvpn(プレミアムVPN/vpn/4687FF)/expressvpn(高速高信頼VPN/vpn/DA3940)/protonvpn(スイス発OSS VPN/vpn/6D4AFF)の3社追加(618→621社)。sitemap 628 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
