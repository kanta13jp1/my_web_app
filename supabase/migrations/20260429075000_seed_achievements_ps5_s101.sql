-- PS#5 S101: anon-guard for admin_analytics_page.dart (4 methods)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S101: admin_analytics anon-guard 4メソッド追加',
  '認証チェック漏れの4メソッド(_loadAdminUsers/_updateFeedbackStatus/_adminUpdateUserProfile/_loadGrowthSummary)にcurrentUser==nullガード追加。dart format + flutter analyze 0確認済み。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
