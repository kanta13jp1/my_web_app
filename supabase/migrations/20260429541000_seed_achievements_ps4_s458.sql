-- PS#4 S458: 競合3社追加 1195→1198社 (brave/1password/surfshark)
-- SEO: "Brave代替"/"1Password代替"/"Surfshark代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S458: 競合3社追加 1195→1198社 (brave/1password/surfshark)',
  'comparison_page.dartにbrave(プライバシーブラウザ広告ブロックBAT報酬Tor Leo AI/FF6000)/1password(パスワードマネージャーTravel Mode/Watchtower/パスキー/1A8CFF)/surfshark(VPN無制限デバイスCleanWeb Nexus Alert/1DBAB9)の3社追加(1195→1198社)。sitemap 1291 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
