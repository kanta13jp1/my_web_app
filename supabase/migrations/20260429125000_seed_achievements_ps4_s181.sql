-- PS#4 S181: 競合3社追加 414→417社 (height/plane/paymo)
-- SEO: "Height代替"/"Plane代替"/"Paymo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S181: 競合3社追加 414→417社 (height/plane/paymo)',
  'comparison_page.dartにheight(AIプロジェクト管理/pm/7B68EE)/plane(OSS Jira代替/pm/3F76FF)/paymo(フリーランスPJ管理/pm/E1554C)の3社追加(414→417社)。sitemap 460 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
