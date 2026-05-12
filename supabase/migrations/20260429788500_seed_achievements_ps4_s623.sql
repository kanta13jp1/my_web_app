-- PS#4 S623: 競合3社追加 死活監視/ステータスページ (pingdom/uptimerobot/instatus)
-- SEO: "Pingdom代替"/"UptimeRobot代替"/"Instatus代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S623: 競合3社追加 (pingdom/uptimerobot/instatus)',
  'comparison_page.dartにpingdom(Webパフォーマンス監視・死活監視・ページスピード・SolarWinds傘下/FF7200)/uptimerobot(無料死活監視50モニター・ステータスページ・Slack/メール通知/3DBD6E)/instatus(モダンステータスページ・高速・カスタムドメイン・SEO最適化/6C47FF)の3社追加(1690社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
