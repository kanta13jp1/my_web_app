-- PS#4 S342: 競合3社追加 897→900社 (mubert/play-ht/murf)
-- SEO: "Mubert代替"/"Play.ht代替"/"Murf代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S342: 競合3社追加 897→900社 (mubert/play-ht/murf)',
  'comparison_page.dartにmubert(AIジェネラティブ音楽BGM生成/music-gen/00B4D8)/play-ht(AIテキストto音声ポッドキャスト/voice-ai/6366F1)/murf(AIボイスオーバープロナレーション/voice-ai/E11D48)の3社追加(897→900社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
