-- PS#4 S570: 競合3社追加 継続 (veeam/acronis/commvault)
-- SEO: "Veeam代替"/"Acronis代替"/"Commvault代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S570: 競合3社追加 (veeam/acronis/commvault)',
  'comparison_page.dartにveeam(Backup & Replication・ランサムウェア対策・マルチクラウド・BCDR/00B336)/acronis(Cyber Protect・バックアップ+セキュリティ統合・クラウド/エンドポイント/E61B23)/commvault(Complete Data Protection・DR・クラウド・ハイブリッド/003DA5)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
