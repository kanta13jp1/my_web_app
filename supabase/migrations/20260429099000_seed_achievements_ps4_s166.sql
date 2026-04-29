-- PS#4 S166: 競合3社追加 369→372社 (bamboohr/rippling/retool)
-- SEO: "BambooHR代替"/"Rippling代替"/"Retool代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S166: 競合3社追加 369→372社 (bamboohr/rippling/retool)',
  'comparison_page.dartにbamboohr(中小企業HR/hr/73C41D)/rippling(HR+IT統合/hr/FFB800)/retool(社内ツール構築/devtools/3C6EE6)の3社追加(369→372社)。sitemap 415 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
