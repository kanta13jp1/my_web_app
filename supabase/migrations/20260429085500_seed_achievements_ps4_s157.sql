-- PS#4 S157: 競合3社追加 342→345社 (brain-fm/focus-at-will/forest)
-- SEO: "Brain.fm代替"/"Focus@Will代替"/"Forest代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S157: 競合3社追加 342→345社 (brain-fm/focus-at-will/forest)',
  'comparison_page.dartにbrain-fm(AI生成集中神経音楽/focus/2196F3)/focus-at-will(神経科学ベース集中BGM/focus/FF5722)/forest(スマホ離れポモドーロ/focus/4CAF50)の3社追加(342→345社)。新カテゴリ:focus。全ファイル348統一。sitemap 638 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
