-- PS#4 S290: 競合3社追加 741→744社 (litmos/ispring/articulate)
-- SEO: "SAP Litmos代替"/"iSpring代替"/"Articulate代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S290: 競合3社追加 741→744社 (litmos/ispring/articulate)',
  'comparison_page.dartにlitmos(SAP製クラウドLMSコンテンツライブラリ/education/0870C1)/ispring(eラーニングオーサリングPowerPoint統合/education/00B451)/articulate(Storyline/Rise eラーニングスイート/education/D84040)の3社追加(741→744社)。sitemap 787 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
