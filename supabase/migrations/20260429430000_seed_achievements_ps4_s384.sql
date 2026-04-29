-- PS#4 S384: 競合3社追加 1023→1026社 (teamcity/buildkite/better-uptime)
-- SEO: "TeamCity代替"/"Buildkite代替"/"Better Uptime代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S384: 競合3社追加 1023→1026社 (teamcity/buildkite/better-uptime)',
  'comparison_page.dartにteamcity(JetBrains CI/CDビルド自動化/ci-cd/21D789)/buildkite(高速スケーラブルCI/CD自前エージェント/ci-cd/14CC80)/better-uptime(インシデントアラートステータスページ稼働率/monitoring/1B6BFF)の3社追加(1023→1026社)。sitemap 1075 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
