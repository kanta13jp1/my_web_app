-- PS#4 S168: 競合3社追加 375→378社 (posthog/jotform/shortcut)
-- SEO: "PostHog代替"/"Jotform代替"/"Shortcut代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S168: 競合3社追加 375→378社 (posthog/jotform/shortcut)',
  'comparison_page.dartにposthog(OSS分析/analytics/F54E00)/jotform(フォーム作成/forms/FF6B00)/shortcut(スプリント管理/devtools/7C3AED)の3社追加(375→378社)。sitemap 421 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
