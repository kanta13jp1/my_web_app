-- PS#4 S403: 競合3社追加 1033→1036社 (chatfuel/manychat/voiceflow)
-- SEO: "Chatfuel代替"/"ManyChat代替"/"Voiceflow代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S403: 競合3社追加 1033→1036社 (chatfuel/manychat/voiceflow)',
  'comparison_page.dartにchatfuel(Facebook/Instagram向けAIチャットボットマーケティング自動化/chatbot/00B0FF)/manychat(Instagram/Facebook/WhatsApp DM自動化チャットマーケティング/chatbot/7B68EE)/voiceflow(ノーコードAIエージェント会話型AIビルダー/chatbot/6B46C1)の3社追加(1033→1036社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
