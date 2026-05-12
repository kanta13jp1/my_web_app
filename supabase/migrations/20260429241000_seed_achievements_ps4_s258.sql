-- PS#4 S258: 競合3社追加 645→648社 (fivetran/dbt-labs/prefect)
-- SEO: "Fivetran代替"/"dbt代替"/"Prefect代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S258: 競合3社追加 645→648社 (fivetran/dbt-labs/prefect)',
  'comparison_page.dartにfivetran(マネージドETL/data-pipeline/0073E6)/dbt-labs(SQL ELT変換/data-pipeline/FF694A)/prefect(Pythonワークフロー/orchestration/24FF9B)の3社追加(645→648社)。sitemap 655 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
