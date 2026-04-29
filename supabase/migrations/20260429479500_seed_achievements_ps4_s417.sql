-- PS#4 S417: 競合3社追加 1075→1078社 (buildium/appfolio/guesty)
-- SEO: "Buildium代替"/"AppFolio代替"/"Guesty代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S417: 競合3社追加 1075→1078社 (buildium/appfolio/guesty)',
  'comparison_page.dartにbuildium(不動産管理テナント管理家賃収集メンテナンス追跡/property-mgmt/006534)/appfolio(AI不動産管理大規模ポートフォリオ投資家レポーティング/property-mgmt/0063BE)/guesty(民泊短期賃貸管理チャンネルマネージャー収益最適化/str-mgmt/4B3CFF)の3社追加(1075→1078社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
