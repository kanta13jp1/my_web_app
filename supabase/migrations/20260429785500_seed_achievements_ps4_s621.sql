-- PS#4 S621: 競合3社追加 ログ管理/SIEM (logzio/sumologic/statuspage)
-- SEO: "Logz.io代替"/"Sumo Logic代替"/"Statuspage代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S621: 競合3社追加 (logzio/sumologic/statuspage)',
  'comparison_page.dartにlogzio(ELKスタックSaaS・AIアラート・OpenSearch・セキュリティ分析/1F6BFF)/sumologic(クラウドネイティブSIEM・ログ分析・脅威インテリジェンス/000099)/statuspage(Atlassian・インシデント管理・ステータスページ・Jira統合/0052CC)の3社追加(1690社)。sitemap 1786 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
