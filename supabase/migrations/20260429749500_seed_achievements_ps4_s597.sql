-- PS#4 S597: 競合3社追加 継続 (pinecone/opensearch-vector/faiss)
-- SEO: "Pinecone代替"/"OpenSearch Vector代替"/"FAISS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S597: 競合3社追加 (pinecone/opensearch-vector/faiss)',
  'comparison_page.dartにpinecone(マネージドベクターDB・高速類似度検索・RAG/24B36B)/opensearch-vector(ベクター検索・k-NN・ハイブリッド・Elasticsearch互換/005EB8)/faiss(Facebook AI・高速類似度検索・GPU対応・大規模ベクター/1877F2)の3社追加(1618社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
