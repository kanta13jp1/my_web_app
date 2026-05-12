-- PS#4 S601: 競合3社追加 継続 (arangodb/cassandra/couchdb)
-- SEO: "ArangoDB代替"/"Apache Cassandra代替"/"CouchDB代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S601: 競合3社追加 (arangodb/cassandra/couchdb)',
  'comparison_page.dartにarangodb(マルチモデルDB・グラフ/ドキュメント/KV・AQL・OSS/68BC43)/cassandra(分散NoSQL・高可用性・線形スケール・時系列/1287B1)/couchdb(ドキュメントDB・MapReduce・HTTP API・オフライン同期・PouchDB/E42528)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
