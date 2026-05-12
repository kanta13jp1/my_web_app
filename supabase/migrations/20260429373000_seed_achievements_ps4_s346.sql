-- PS#4 S346: 競合3社追加 909→912社 (notta/deepgram/assembly-ai)
-- SEO: "Notta代替"/"Deepgram代替"/"AssemblyAI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S346: 競合3社追加 909→912社 (notta/deepgram/assembly-ai)',
  'comparison_page.dartにnotta(AI音声文字起こし多言語会議記録/transcription/4F46E5)/deepgram(エンタープライズ音声AI高速STT API/speech-api/13EF93)/assembly-ai(オーディオインテリジェンスLLM統合/speech-api/6366F1)の3社追加(909→912社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
