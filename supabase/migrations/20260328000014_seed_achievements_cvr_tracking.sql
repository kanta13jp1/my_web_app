-- Session daily-development: 比較ページ CVR トラッキング実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '比較ページ CVR トラッキング実装',
  '/vs-notion・/vs-slack など14比較ページの訪問を GrowthAcquisitionService で計測。touch_comparison_{key} シグナル記録・signup_submit_comparison で登録CVRを競合別に追跡可能に。StatelessWidget→StatefulWidget安全移行も実施。',
  '2026-03-28'
)
ON CONFLICT DO NOTHING;
