-- PS#4 S593: 競合3社追加 継続 (firebolt/duckdb/clickhouse)
-- SEO: "Firebolt代替"/"DuckDB代替"/"ClickHouse代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S593: 競合3社追加 (firebolt/duckdb/clickhouse)',
  'comparison_page.dartにfirebolt(次世代クラウドDWH・超高速分析・インデックス最適化/FF6B35)/duckdb(インプロセス分析DB・列指向・Parquet/CSV・Python/R統合/FFB600)/clickhouse(超高速OLAP・列指向DB・リアルタイム分析・OSS/FFCC00)の3社追加(1600社)。sitemap 1696 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
