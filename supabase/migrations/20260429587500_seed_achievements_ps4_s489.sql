-- PS#4 S489: 競合3社追加 1287→1296社 (ulysses/ia-writer/scrivener)
-- SEO: "Ulysses代替"/"iA Writer代替"/"Scrivener代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S489: 競合3社追加 1287→1296社 (ulysses/ia-writer/scrivener)',
  'comparison_page.dartにulysses(Mac/iPhone執筆iCloud同期Markdown出版直結/FF6F00)/ia-writer(フォーカスライティングカスタムfontMarkdown全プラットフォーム/212121)/scrivener(アウトライナーコルクボードコンパイル出版研究資料管理脚本小説/BF360C)の3社追加(1287→1296社)。sitemap 1390 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
