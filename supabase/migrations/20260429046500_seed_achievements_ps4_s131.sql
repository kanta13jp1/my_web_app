-- PS#4 S131: 競合3社追加 264→267社 (crowdworks/lancers/coconala)
-- SEO: "CrowdWorks代替"/"Lancers代替"/"coconala代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S131: 競合3社追加 264→267社 (crowdworks/lancers/coconala)',
  'comparison_page.dartにcrowdworks(クラウドソーシング仕事マッチング/freelance/0099CC)/lancers(フリーランス案件マッチング/freelance/FF7F00)/coconala(スキル販売シェアマーケット/marketplace/F5B800)の3社追加(264→267社)。新カテゴリfreelance/marketplace追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
