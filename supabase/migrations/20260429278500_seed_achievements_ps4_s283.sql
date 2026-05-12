-- PS#4 S283: 競合3社追加 720→723社 (freshservice/servicenow/degreed)
-- SEO: "Freshservice代替"/"ServiceNow代替"/"Degreed代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S283: 競合3社追加 720→723社 (freshservice/servicenow/degreed)',
  'comparison_page.dartにfreshservice(クラウドITSMサービスデスク/itsm/1CC85A)/servicenow(エンタープライズITSMワークフロー/itsm/81B5A1)/degreed(企業向けスキル構築LXP/learning/004B87)の3社追加(720→723社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
