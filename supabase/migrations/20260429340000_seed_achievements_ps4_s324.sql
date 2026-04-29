-- PS#4 S324: 競合3社追加 843→846社 (egghead/exercism/mimo)
-- SEO: "egghead代替"/"Exercism代替"/"Mimo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S324: 競合3社追加 843→846社 (egghead/exercism/mimo)',
  'comparison_page.dartにegghead(エキスパート開発者向け高密度ビデオコース/learning/1A202C)/exercism(メンター付きコーディング練習言語習得/learning/009CAB)/mimo(スマートフォンコーディング学習モバイルアプリ/learning/4C00FF)の3社追加(843→846社)。sitemap 895 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
