-- PS#4 S103: 超高検索ボリューム競合3社追加 (midjourney/character-ai/deepseek) 183→186社
-- SEO: "Midjourney代替"/"Character AI代替"/"DeepSeek代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S103: 競合3社追加 183→186社 (midjourney/character-ai/deepseek) + ai-image/ai-chatbotカテゴリ新規',
  'comparison_page.dartにmidjourney(AI画像生成/Discord専用/$10~/ai-image新カテゴリ)/character-ai(AIキャラクターチャット/ロールプレイ/$9.99/ai-chatbot新カテゴリ)/deepseek(DeepSeek R1/オープンソースAI推論/無料/ai-platform)の3社追加(183→186社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記183→186統一。Midjourney代替・Character AI代替・DeepSeek代替は超高検索ボリュームキーワード。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
