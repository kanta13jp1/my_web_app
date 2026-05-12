-- PS#4 S498: 競合3社追加 1314→1323社 (loseit/lifesum/yazio)
-- SEO: "Lose It代替"/"Lifesum代替"/"YAZIO代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S498: 競合3社追加 1314→1323社 (loseit/lifesum/yazio)',
  'comparison_page.dartにloseit(カロリー追跡食品スキャンSnap It AIマクロ管理体重グラフ/00BFA5)/lifesum(食事計画マクロビタミンレシピApple Health統合健康スコア/4CAF50)/yazio(カロリー追跡断食タイマー50M食品DB欧州発/F57C00)の3社追加(1314→1323社)。sitemap 1417 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
