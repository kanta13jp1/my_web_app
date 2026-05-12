-- PS#4 S347: 競合3社追加 912→915社 (rev/speak-ai/sonix)
-- SEO: "Rev代替"/"Speak AI代替"/"Sonix代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S347: 競合3社追加 912→915社 (rev/speak-ai/sonix)',
  'comparison_page.dartにrev(AI+人間プロ品質文字起こし字幕99%保証/transcription/047857)/speak-ai(音声動画テキストデータ分析リサーチ/transcription/7C3AED)/sonix(AI自動文字起こし翻訳字幕38言語/transcription/DB2777)の3社追加(912→915社)。sitemap 958 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
