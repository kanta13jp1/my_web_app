-- PS#4 S572: 競合3社追加 継続 (druva/carbonite/zerto)
-- SEO: "Druva代替"/"Carbonite代替"/"Zerto代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S572: 競合3社追加 (druva/carbonite/zerto)',
  'comparison_page.dartにdruva(SaaS型クラウドバックアップ・エンドポイント/クラウド/SaaS・ランサムウェア対策/0082CB)/carbonite(クラウドバックアップ・PC/サーバー・SMB・OpenText/009C3B)/zerto(クラウドDR/BC・リアルタイムレプリケーション・マルチクラウド移行/0063B1)の3社追加(1537社)。sitemap 1633 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
