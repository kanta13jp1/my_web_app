-- PS#4 S300: 競合3社追加 771→774社 (piktochart/infogram/datawrapper)
-- SEO: "Piktochart代替"/"Infogram代替"/"Datawrapper代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S300: 競合3社追加 771→774社 (piktochart/infogram/datawrapper)',
  'comparison_page.dartにpiktochart(インフォグラフィックプレゼンレポート/infographic/00B4D8)/infogram(データビジュアライゼーションインタラクティブチャート/dataviz/7B2D8B)/datawrapper(ジャーナリストメディア向けデータビジュアル/dataviz/3B55E6)の3社追加(771→774社)。sitemap 823 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
