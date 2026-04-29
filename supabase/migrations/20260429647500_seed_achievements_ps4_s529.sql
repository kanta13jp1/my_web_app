-- PS#4 S529: 競合3社追加 継続 (opsgenie/victorops/betterstack)
-- SEO: "Opsgenie代替"/"VictorOps代替"/"Better Stack代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S529: 競合3社追加 (opsgenie/victorops/betterstack)',
  'comparison_page.dartにopsgenie(Atlassian傘下インシデント管理・オンコールスケジュール・アラートルーティング・Jira連携/0052CC)/victorops(Splunk On-Call DevOpsインシデント管理・ChatOps・タイムライン・オンコール自動化/65A637)/betterstack(死活監視+インシデントログ+オンコール+ステータスページ統合・開発者向け/22C55E)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
