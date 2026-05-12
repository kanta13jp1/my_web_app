-- PS#4 S589: 競合3社追加 継続 (apache-pulsar/redpanda/starburst)
-- SEO: "Apache Pulsar代替"/"Redpanda代替"/"Starburst代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S589: 競合3社追加 (apache-pulsar/redpanda/starburst)',
  'comparison_page.dartにapache-pulsar(マルチテナント・ジオレプリケーション・サーバーレス関数/188EFF)/redpanda(Kafka互換・C++実装・JVM不要・高パフォーマンス/FF2B4B)/starburst(マネージドTrino・フェデレーテッドクエリ・データレイクハウス/1E3A5F)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
