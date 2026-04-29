-- PS#4 S580: 競合3社追加 継続 (five9/talkdesk/twilio-flex)
-- SEO: "Five9代替"/"Talkdesk代替"/"Twilio Flex代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S580: 競合3社追加 (five9/talkdesk/twilio-flex)',
  'comparison_page.dartにfive9(AIエージェント・CCaaS・WFO・オムニチャネル・CRM統合/003580)/talkdesk(AIクラウドCC・CX Cloud・リアルタイムAI・WFM/FF3366)/twilio-flex(プログラマブルCCaaS・API・カスタマイズ・デベロッパーファースト/E31837)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
