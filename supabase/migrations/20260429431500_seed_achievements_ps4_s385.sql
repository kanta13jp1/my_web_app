-- PS#4 S385: 競合3社追加 1026→1029社 (uptimerobot/incident-io/infisical)
-- SEO: "UptimeRobot代替"/"incident.io代替"/"Infisical代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S385: 競合3社追加 1026→1029社 (uptimerobot/incident-io/infisical)',
  'comparison_page.dartにuptimerobot(無料稼働率監視HTTP/PINGチェックアラート/monitoring/3D9BE9)/incident-io(Slackインシデント管理ポストモーテムAI要約/incident/FF4B00)/infisical(OSS シークレット管理環境変数PKI/secrets/A855F7)の3社追加(1026→1029社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
