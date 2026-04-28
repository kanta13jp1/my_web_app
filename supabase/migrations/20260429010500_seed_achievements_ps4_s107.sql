-- PS#4 S107: 超高検索ボリューム競合3社追加 (runway/heygen/elevenlabs) 195→198社
-- SEO: "Runway代替"/"HeyGen代替"/"ElevenLabs代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S107: 競合3社追加 195→198社 (runway/heygen/elevenlabs)',
  'comparison_page.dartにrunway(RunwayML Gen-3 AI映像生成/月額$15~/ai-video)/heygen(AIアバター動画生成/月額$29~/ai-video)/elevenlabs(AI音声合成TTS/月額$22~/ai-voice)の3社追加(195→198社)。新カテゴリai-video/ai-voice追加。competitorMeta/sitemap既存登録済み確認。全ファイル社数表記195→198統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
