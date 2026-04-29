-- PS#4 S486: 競合3社追加 1278→1287社 (mondly/cambly/lingodeer)
-- SEO: "Mondly代替"/"Cambly代替"/"LingoDeer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S486: 競合3社追加 1278→1287社 (mondly/cambly/lingodeer)',
  'comparison_page.dartにmondly(41言語AR/VR会話練習ネイティブ音声AIチャットボット/7B2FBE)/cambly(ネイティブ英語講師即時接続24時間録画Kids/FFAB40)/lingodeer(アジア言語特化日韓中文法重視JLPT/HSK対応/4CAF50)の3社追加(1278→1287社)。sitemap 1381 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
