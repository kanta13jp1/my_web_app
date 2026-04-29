-- PS#4 S147: 競合3社追加 312→315社 (zaim/myfitnesspal/khan-academy)
-- SEO: "Zaim代替"/"MyFitnessPal代替"/"Khan Academy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S147: 競合3社追加 312→315社 (zaim/myfitnesspal/khan-academy)',
  'comparison_page.dartにzaim(日本No.1家計簿アプリ/fintech-jp/00B5AD)/myfitnesspal(食事・運動トラッキング/fitness/0043B5)/khan-academy(無料教育プラットフォーム/learning/14BF96)の3社追加(312→315社)。全ファイル315統一。sitemap 611 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
