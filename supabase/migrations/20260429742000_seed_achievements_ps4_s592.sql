-- PS#4 S592: 競合3社追加 継続 (delta-lake/apache-iceberg/apache-hudi)
-- SEO: "Delta Lake代替"/"Apache Iceberg代替"/"Apache Hudi代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S592: 競合3社追加 (delta-lake/apache-iceberg/apache-hudi)',
  'comparison_page.dartにdelta-lake(OSSレイクハウス・ACID・Time Travel・スキーマエンフォース/00ADD8)/apache-iceberg(オープンテーブルフォーマット・マルチエンジン・Time Travel/37474F)/apache-hudi(増分処理・Upsert/Delete・ストリーミング取り込み/F57C00)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
