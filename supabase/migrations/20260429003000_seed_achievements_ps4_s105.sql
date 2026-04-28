-- PS#4 S105: 超高検索ボリューム競合3社追加 (adobe-firefly/leonardo-ai/poe) 189→192社
-- SEO: "Adobe Firefly代替"/"Leonardo AI代替"/"Poe代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S105: 競合3社追加 189→192社 (adobe-firefly/leonardo-ai/poe)',
  'comparison_page.dartにadobe-firefly(Creative Cloud AI画像/月額数千円/ai-image)/leonardo-ai(ゲームアート特化AI画像/月額$12~/ai-image)/poe(Quora マルチAIアグリゲーター/月額$19.99/ai-platform)の3社追加(189→192社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記189→192統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
