-- PS#4 S600: 競合3社追加 継続 (neo4j/amazon-neptune/tigergraph)
-- SEO: "Neo4j代替"/"Amazon Neptune代替"/"TigerGraph代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S600: 競合3社追加 (neo4j/amazon-neptune/tigergraph)',
  'comparison_page.dartにneo4j(グラフDB・Cypher・知識グラフ・推薦エンジン/018BFF)/amazon-neptune(マネージドグラフDB・Gremlin/SPARQL/openCypher・AWS統合/527FFF)/tigergraph(エンタープライズグラフDB・GSQL・AI/ML統合・詐欺検知/FF6600)の3社追加(1627社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
