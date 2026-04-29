-- PS#4 S230: 競合3社追加 561→564社 (bugsnag/rollbar/logrocket)
-- SEO: "Bugsnag代替"/"Rollbar代替"/"LogRocket代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S230: 競合3社追加 561→564社 (bugsnag/rollbar/logrocket)',
  'comparison_page.dartにbugsnag(アプリ安定性/monitoring/4C4C96)/rollbar(リアルタイムエラー/monitoring/33CCFF)/logrocket(セッションリプレイ/monitoring/764ABC)の3社追加(561→564社)。sitemap 607 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
