-- PS#4 S410: 競合3社追加 1054→1057社 (kickstarter/indiegogo/mercury)
-- SEO: "Kickstarter代替"/"Indiegogo代替"/"Mercury代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S410: 競合3社追加 1054→1057社 (kickstarter/indiegogo/mercury)',
  'comparison_page.dartにkickstarter(クラウドファンディングプロジェクト資金調達バッカーコミュニティ/crowdfunding/05CE78)/indiegogo(柔軟なクラウドファンディングInDemand継続販売グローバル/crowdfunding/EB1478)/mercury(スタートアップ向けビジネスバンキングAPI財務インフラ/fintech/0D0D0D)の3社追加(1054→1057社)。sitemap 1147 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
