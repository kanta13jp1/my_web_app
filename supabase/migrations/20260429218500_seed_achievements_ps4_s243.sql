-- PS#4 S243: 競合3社追加 600→603社 (pinecone/weaviate/qdrant)
-- SEO: "Pinecone代替"/"Weaviate代替"/"Qdrant代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S243: 競合3社追加 600→603社 (pinecone/weaviate/qdrant)',
  'comparison_page.dartにpinecone(マネージドベクターDB/vector-db/00B4D8)/weaviate(OSSベクターDB/GraphQL/vector-db/3EC9A7)/qdrant(Rust製高速ベクター検索/vector-db/DC143C)の3社追加(600→603社)。sitemap 610 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
