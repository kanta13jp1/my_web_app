-- PS#4 S319: 競合3社追加 828→831社 (cockroachdb/tidb-cloud/nhost)
-- SEO: "CockroachDB代替"/"TiDB代替"/"Nhost代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S319: 競合3社追加 828→831社 (cockroachdb/tidb-cloud/nhost)',
  'comparison_page.dartにcockroachdb(グローバル分散NewSQL PostgreSQL互換/db/6933FF)/tidb-cloud(HTAP分散MySQL互換OLTP+OLAP/db/E05D44)/nhost(OSS Firebase代替GraphQL BaaS/baas/0052CD)の3社追加(828→831社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
