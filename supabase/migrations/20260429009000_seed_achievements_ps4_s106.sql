-- PS#4 S106: 超高検索ボリューム競合3社追加 (suno/udio/ideogram) 192→195社
-- SEO: "Suno代替"/"Udio代替"/"Ideogram代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S106: 競合3社追加 192→195社 (suno/udio/ideogram)',
  'comparison_page.dartにsuno(Suno AI音楽生成/月額約10USD/ai-music)/udio(Udio AI楽曲生成/月額約10USD/ai-music)/ideogram(テキスト埋め込みAI画像/月額約8USD/ai-image)の3社追加(192→195社)。新カテゴリai-music追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記192→195統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
