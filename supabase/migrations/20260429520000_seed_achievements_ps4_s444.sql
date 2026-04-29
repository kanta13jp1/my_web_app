-- PS#4 S444: 競合3社追加 1156→1159社 (missive/mattermost/rocketchat)
-- SEO: "Missive代替"/"Mattermost代替"/"Rocket.Chat代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S444: 競合3社追加 1156→1159社 (missive/mattermost/rocketchat)',
  'comparison_page.dartにmissive(チームメール+チャット統合受信箱コラボ返信ルール/team-email/3A49E0)/mattermost(OSSSlack代替セルフホストE2E暗号化DevOps統合/team-chat/1B5FB3)/rocketchat(OSSチームメッセージングOmnichannelAI統合/team-chat/F5455C)の3社追加(1156→1159社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
