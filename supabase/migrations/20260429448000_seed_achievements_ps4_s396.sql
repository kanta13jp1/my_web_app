-- PS#4 S396: 競合3社追加 1012→1015社 (optimizely/launchdarkly/split-io)
-- SEO: "Optimizely代替"/"LaunchDarkly代替"/"Split.io代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S396: 競合3社追加 1012→1015社 (optimizely/launchdarkly/split-io)',
  'comparison_page.dartにoptimizely(A/Bテスト実験プラットフォームフィーチャーフラグCMS/experimentation/006BFF)/launchdarkly(フィーチャーフラグ段階ロールアウト実験/feature-flags/405BFF)/split-io(フラグ×実験統合CUPED統計インパクト測定/feature-flags/1C1C1E)の3社追加(1012→1015社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
