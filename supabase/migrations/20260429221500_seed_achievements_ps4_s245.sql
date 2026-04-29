-- PS#4 S245: 競合3社追加 606→609社 (redis-vector/pgvector/vespa)
-- SEO: "Redis Vector Search代替"/"pgvector代替"/"Vespa代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S245: 競合3社追加 606→609社 (redis-vector/pgvector/vespa)',
  'comparison_page.dartにredis-vector(Redis VSS/インメモリ高速/vector-db/FF4438)/pgvector(PostgreSQL OSS拡張/Supabase統合/vector-db/336791)/vespa(Yahoo OSS/MLランキング/vector-db/0A6EBD)の3社追加(606→609社)。sitemap 610 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
