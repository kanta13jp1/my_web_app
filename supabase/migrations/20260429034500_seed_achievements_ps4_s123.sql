-- PS#4 S123: 競合3社追加 240→243社 (sprout-social/deel/smartsheet)
-- SEO: "Sprout Social代替"/"Deel代替"/"Smartsheet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S123: 競合3社追加 240→243社 (sprout-social/deel/smartsheet)',
  'comparison_page.dartにsprout-social(エンタープライズSNS管理/social-media/59CB59)/deel(グローバル雇用・給与/hr/5A45FF)/smartsheet(スプレッドシートPM/project/0073E6)の3社追加(240→243社)。competitorMeta/sitemap/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
