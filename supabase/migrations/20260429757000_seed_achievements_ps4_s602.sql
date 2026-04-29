-- PS#4 S602: 競合3社追加 継続 (couchbase/janusgraph/dgraph)
-- SEO: "Couchbase代替"/"JanusGraph代替"/"Dgraph代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S602: 競合3社追加 (couchbase/janusgraph/dgraph)',
  'comparison_page.dartにcouchbase(マルチモデルNoSQL・N1QL・メモリファースト・モバイル同期/ED2226)/janusgraph(OSSスケーラブルグラフDB・Gremlin・Cassandra対応/4A4A8A)/dgraph(ネイティブグラフDB・GraphQL・DQL・分散・高パフォーマンス/00C8FF)の3社追加(1627社)。sitemap 1723 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
