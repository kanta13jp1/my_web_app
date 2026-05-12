-- PS#4 S379: 競合3社追加 1008→1011社 (vultr/hetzner/neon-db)
-- SEO: "Vultr代替"/"Hetzner代替"/"Neon代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S379: 競合3社追加 1008→1011社 (vultr/hetzner/neon-db)',
  'comparison_page.dartにvultr(グローバルクラウドインフラ高パフォーマンスVPS/cloud/009BDE)/hetzner(ヨーロッパ高コスパクラウドサーバー/cloud/D50C2D)/neon-db(サーバーレスPostgresブランチ機能/serverless-db/00E5A0)の3社追加(1008→1011社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
