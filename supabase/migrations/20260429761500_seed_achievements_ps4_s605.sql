-- PS#4 S605: 競合3社追加 継続 (druid/kdb/opentsdb)
-- SEO: "Apache Druid代替"/"kdb+代替"/"OpenTSDB代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S605: 競合3社追加 (druid/kdb/opentsdb)',
  'comparison_page.dartにdruid(リアルタイム分析DB・OLAP・高速集計・Kafka統合/29ABE2)/kdb+(金融時系列DB・q言語・超高速・高頻度取引/003087)/opentsdb(OSSスケーラブル時系列DB・HBase・Graphite互換/607D8B)の3社追加(1636社)。sitemap 1732 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
