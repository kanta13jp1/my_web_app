-- PS#4 S571: 競合3社追加 継続 (veritas/cohesity/rubrik)
-- SEO: "Veritas代替"/"Cohesity代替"/"Rubrik代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S571: 競合3社追加 (veritas/cohesity/rubrik)',
  'comparison_page.dartにveritas(NetBackup・データ保護・eDiscovery・コンプライアンス/003DA5)/cohesity(DataProtect・AI駆動データ管理・ランサムウェア復旧・クラウドネイティブ/0070C0)/rubrik(Security Cloud・ランサムウェア防御・データ可観測性/FF6B35)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
