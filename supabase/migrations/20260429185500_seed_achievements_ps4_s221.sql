-- PS#4 S221: 競合3社追加 534→537社 (acuity/setmore/simplybook)
-- SEO: "Acuity Scheduling代替"/"Setmore代替"/"SimplyBook代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S221: 競合3社追加 534→537社 (acuity/setmore/simplybook)',
  'comparison_page.dartにacuity(Squarespace予約管理/scheduling/3D8FE0)/setmore(無料予約システム/scheduling/4A90D9)/simplybook(業種別予約/scheduling/1CB289)の3社追加(534→537社)。sitemap 580 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
