-- PS#4 S473: 競合3社追加 1240→1243社 (things-3/any-do/paprika)
-- SEO: "Things 3代替"/"Any.do代替"/"Paprika代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S473: 競合3社追加 1240→1243社 (things-3/any-do/paprika)',
  'comparison_page.dartにthings-3(Apple専用プレミアムToDo買い切りデザイン賞/3F79F3)/any-do(AI計画カレンダーデイリープランナーレシピ習慣/E03131)/paprika(レシピ管理Webクリッパー食材リストミールプラン/EA4C3A)の3社追加(1240→1243社)。sitemap 1336 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
