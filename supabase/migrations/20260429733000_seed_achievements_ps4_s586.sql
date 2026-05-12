-- PS#4 S586: 競合3社追加 継続 (monte-carlo/dbt-cloud/apache-atlas)
-- SEO: "Monte Carlo代替"/"dbt Cloud代替"/"Apache Atlas代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S586: 競合3社追加 (monte-carlo/dbt-cloud/apache-atlas)',
  'comparison_page.dartにmonte-carlo(データオブザーバビリティ・品質モニタリング・異常検知・インシデント管理/00BCD4)/dbt-cloud(データ変換・SQLベースELT・データモデリング・リネージ/FF694A)/apache-atlas(OSSデータガバナンス・メタデータ・Hadoop・タグ分類/E84393)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
