-- PS#4 S590: 競合3社追加 継続 (trino/apache-beam/apache-hive)
-- SEO: "Trino代替"/"Apache Beam代替"/"Apache Hive代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S590: 競合3社追加 (trino/apache-beam/apache-hive)',
  'comparison_page.dartにtrino(OSSフェデレーテッドSQL・高速分散クエリ・データレイク/DD00A1)/apache-beam(統合バッチ/ストリームモデル・ポータブルパイプライン・Dataflow対応/4A90D9)/apache-hive(HiveQL・Hadoopデータウェアハウス・HDFS・メタストア/FDBE00)の3社追加(1591社)。sitemap 1687 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
