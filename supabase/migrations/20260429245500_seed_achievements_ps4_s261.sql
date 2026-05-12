-- PS#4 S261: 競合3社追加 654→657社 (greenhouse/lever/ashby)
-- SEO: "Greenhouse代替"/"Lever代替"/"Ashby代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S261: 競合3社追加 654→657社 (greenhouse/lever/ashby)',
  'comparison_page.dartにgreenhouse(採用管理ATS/hr/24A148)/lever(ATS+CRM統合採用/hr/00B3E3)/ashby(次世代採用プラットフォーム/hr/6B21A8)の3社追加(654→657社)。sitemap 664 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
