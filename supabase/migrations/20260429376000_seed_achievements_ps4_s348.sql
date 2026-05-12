-- PS#4 S348: 競合3社追加 915→918社 (trint/happy-scribe/lalal-ai)
-- SEO: "Trint代替"/"Happy Scribe代替"/"LALAL.AI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S348: 競合3社追加 915→918社 (trint/happy-scribe/lalal-ai)',
  'comparison_page.dartにtrint(AIジャーナリスト向け文字起こし編集/transcription/0EA5E9)/happy-scribe(AI自動文字起こし翻訳字幕119言語/transcription/F59E0B)/lalal-ai(AIステムセパレーターボーカル楽器分離/audio-tools/7C3AED)の3社追加(915→918社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
