-- PowerShell 全体管理セッション #2 実績シード 2026-03-31

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'サイトマップ40URL更新 (public-memos・選挙・紹介追加)',
    'web/sitemap.xmlに /public-memos・/local-election-700・/local-election-schedule・/referral を追加し36→40URLに拡充。LP・ユーザーマニュアルのlastmodを2026-03-31に更新。SEO クロール優先度を調整。Google Search Console 再送信の準備完了。',
    '2026-03-31'
  ),
  (
    'AdminダッシュボードCVRカード完全統合',
    '比較ページCVRトラッキングをAdminダッシュボードに統合完了。admin_analytics_pageに_buildComparisonCvrCard()を追加し、app_analyticsのsource_details JSONBから全競合別到達数・CVR%をリアルタイム表示。4インスタンス並列開発で競合なく統合。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
