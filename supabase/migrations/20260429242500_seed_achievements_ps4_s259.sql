-- PS#4 S259: 競合3社追加 648→651社 (dagster/fullstory/gainsight)
-- SEO: "Dagster代替"/"FullStory代替"/"Gainsight代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S259: 競合3社追加 648→651社 (dagster/fullstory/gainsight)',
  'comparison_page.dartにdagster(データオーケストレーション/orchestration/4F5BD5)/fullstory(セッション録画UX分析/analytics/1B1B1B)/gainsight(B2B顧客サクセス/crm/0070D2)の3社追加(648→651社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
