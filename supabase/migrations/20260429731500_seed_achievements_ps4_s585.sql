-- PS#4 S585: 競合3社追加 継続 (alation/collibra/atlan)
-- SEO: "Alation代替"/"Collibra代替"/"Atlan代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S585: 競合3社追加 (alation/collibra/atlan)',
  'comparison_page.dartにalation(データカタログ・データリテラシー・コラボレーション・ML推奨/0078D4)/collibra(データガバナンス・ビジネス用語集・ポリシー管理・コンプライアンス/5A1FBE)/atlan(モダンデータカタログ・データメッシュ・AI自動化・Slack統合/5865F2)の3社追加(1582社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
