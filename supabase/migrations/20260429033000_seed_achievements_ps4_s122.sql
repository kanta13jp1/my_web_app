-- PS#4 S122: 競合3社追加 237→240社 (later/rytr/gusto)
-- SEO: "Later代替"/"Rytr代替"/"Gusto代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S122: 競合3社追加 237→240社 (later/rytr/gusto)',
  'comparison_page.dartにlater(ビジュアルSNSスケジューリング/social-media/5000E8)/rytr(AIライティング/ai-writing/4557FF)/gusto(HR・給与計算/hr/45C4B0)の3社追加。新カテゴリhr追加。sitemap283URLs/全ファイル社数表記240統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
