-- PS#4 S99: 高検索ボリューム競合2社追加 (codeium/gemini)
-- SEO: "Codeium代替"/"Google Gemini代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S99: 競合2社追加 177→179社 (codeium/gemini)',
  'comparison_page.dart _competitorInfo に codeium/gemini の2社追加(177→179社)。competitorMeta(index.html) + sitemap.xml(+2URL) も更新。_categoryOf にai-dev/ai-platform分類追加。Gemini代替は高検索ボリュームキーワード。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
