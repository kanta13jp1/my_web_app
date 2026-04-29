-- PS#4 S149: 競合3社追加 318→321社 (slite/gitbook/fibery)
-- SEO: "Slite代替"/"GitBook代替"/"Fibery代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S149: 競合3社追加 318→321社 (slite/gitbook/fibery)',
  'comparison_page.dartにslite(AIチームナレッジベース/notes/3772FF)/gitbook(技術ドキュメントハブ/notes/3884FF)/fibery(ノーコード統合ワークスペース/notes/7A28CB)の3社追加(318→321社)。全ファイル321統一。sitemap 611 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
