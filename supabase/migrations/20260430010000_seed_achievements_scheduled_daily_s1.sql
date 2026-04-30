-- Scheduled daily-development task: 2026-04-30
-- Blog draft for memory-search-hub EF (BM25 + pgvector hybrid + Haiku rerank)

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Blog Draft: Memory Search Hub — BM25 + pgvector Hybrid Search',
  'Wrote English technical blog draft covering the memory-search-hub Edge Function: BM25 with CJK bigram tokenizer, pgvector recall, Haiku 4.5 reranker, task_budget cost guards, and mcp_auth_guard scope checks. Documents the 20/50 EF deploy-prod milestone and effort_router/task_budget stub-to-implementation transition. Draft saved to docs/blog-drafts/2026-04-30-memory-search-hub-bm25-vector-hybrid-en.md (published: false, ready for review).',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
