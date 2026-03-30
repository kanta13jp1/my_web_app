-- Session: 比較ページCVRトラッキング強化・管理者ダッシュボード拡張 (2026-03-31)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '比較ページCVRトラッキング完成',
    '21競合の比較ページ経由の登録CVRを計測・可視化。touch_comparison/signup_submit_comparisonシグナルをgrowth_acquisition_signal_pageとadmin_analytics_pageに追加。管理者ダッシュボードに比較ページ別CVRカード（競合別到達数バー・CVR%）を実装。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
