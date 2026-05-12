-- PS#4 S343: 競合3社追加 900→903社 (resemble-ai/krisp/wellsaid)
-- SEO: "Resemble AI代替"/"Krisp代替"/"WellSaid代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S343: 競合3社追加 900→903社 (resemble-ai/krisp/wellsaid)',
  'comparison_page.dartにresemble-ai(ボイスクローンリアルタイム音声変換/voice-ai/0F766E)/krisp(AIノイズキャンセリング会議音声クリア/voice-ai/7C3AED)/wellsaid(エンタープライズTTS高品質ナレーション/voice-ai/1D4ED8)の3社追加(900→903社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
