-- PS#4 S345: 競合3社追加 906→909社 (speechify/otter-ai/fireflies)
-- SEO: "Speechify代替"/"Otter.ai代替"/"Fireflies代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S345: 競合3社追加 906→909社 (speechify/otter-ai/fireflies)',
  'comparison_page.dartにspeechify(AI音声読み上げテキストto音声学習/voice-ai/7C3AED)/otter-ai(AI会議文字起こしリアルタイム議事録/transcription/0EA5E9)/fireflies(AI会議録音文字起こし知識管理/transcription/EF4444)の3社追加(906→909社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
