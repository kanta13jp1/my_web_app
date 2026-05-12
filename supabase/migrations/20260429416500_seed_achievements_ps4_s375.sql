-- PS#4 S375: 競合3社追加 996→999社 (papertrail/loggly/sumo-logic)
-- SEO: "Papertrail代替"/"Loggly代替"/"Sumo Logic代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S375: 競合3社追加 996→999社 (papertrail/loggly/sumo-logic)',
  'comparison_page.dartにpapertrail(クラウドログ管理リアルタイム検索アラート/log-mgmt/1A9FD6)/loggly(SaaS向けクラウドログ分析インサイト/log-mgmt/38A169)/sumo-logic(クラウドネイティブSIEMログ分析/siem/0073CF)の3社追加(996→999社)。sitemap 1048 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
