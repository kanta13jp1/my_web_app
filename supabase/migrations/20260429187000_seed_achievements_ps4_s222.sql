-- PS#4 S222: 競合3社追加 537→540社 (twilio/vonage/plivo)
-- SEO: "Twilio代替"/"Vonage代替"/"Plivo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S222: 競合3社追加 537→540社 (twilio/vonage/plivo)',
  'comparison_page.dartにtwilio(クラウドコミュニケーションAPI/communication-api/F22F46)/vonage(Ericsson通信API/communication-api/00003B)/plivo(コスト効率SMS音声/communication-api/0B6BFB)の3社追加(537→540社)。sitemap 589 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
