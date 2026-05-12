-- PS#4 S260: 競合3社追加 651→654社 (help-scout/statsig/vwo)
-- SEO: "Help Scout代替"/"Statsig代替"/"VWO代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S260: 競合3社追加 651→654社 (help-scout/statsig/vwo)',
  'comparison_page.dartにhelp-scout(カスタマーサポート共有受信トレイ/support/1292EE)/statsig(フィーチャーゲート+A/B/analytics/194BFB)/vwo(ビジュアルA/Bテスト/analytics/0DA4CE)の3社追加(651→654社)。sitemap 655 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
