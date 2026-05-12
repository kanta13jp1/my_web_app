-- PS#3 S133: AI大学 360→362社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S133: Haystack 追加 — 360→361社',
    'Haystack (deepset/ドイツ / エンタープライズRAGフレームワーク / LLMパイプライン / Component+Pipeline+DocumentStore / BM25+ベクトルハイブリッド / Apache-2.0 / deepset Cloud / GDPR準拠) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S133: Phidata 追加 — 361→362社',
    'Phidata (旧phidata→Agno / フルスタックAI開発基盤 / Agent+Memory+Knowledge+Tools 4柱 / PostgreSQL+pgvector / FastAPI自動生成 / Long-term Memory永続化 / ハイブリッド検索 / OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
