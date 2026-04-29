-- PS#4 S465: 競合3社追加 1216→1219社 (disney-plus/apple-tv-plus/crunchyroll)
-- SEO: "Disney+代替"/"Apple TV+代替"/"Crunchyroll代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S465: 競合3社追加 1216→1219社 (disney-plus/apple-tv-plus/crunchyroll)',
  'comparison_page.dartにdisney-plus(Disney/Marvel/Star Wars/Pixar/NatGeo 4K HDR/113CCF)/apple-tv-plus(Appleオリジナル Ted Lasso Severance/555555)/crunchyroll(アニメ専門1000+タイトル同時放送マンガ/F47521)の3社追加(1216→1219社)。sitemap 1318 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
