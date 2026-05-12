-- PS版#2 S83: T-1 Phase32 全4弾完結 (#155-#158) dev.to累計158本
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 第155弾: Flutter i18n ローカライズ完全ガイド', 'flutter_localizations + intl + Riverpod 動的切り替え + Supabase 永続化。dev.to投稿: flutter-localization-complete-guide', '2026-04-29'),
  ('T-1 第156弾: Supabase Auth OAuth・Magic Link・RLS', 'Google OAuth + Magic Link + Row Level Security + Edge Function 認証確認。dev.to投稿: supabase-auth-complete-guide', '2026-04-29'),
  ('T-1 第157弾: インディー開発者のASO完全ガイド', 'キーワード戦略 + スクリーンショット最適化 + レビュー自動化 + A/B テスト。dev.to投稿: indie-dev-aso-complete-guide', '2026-04-29'),
  ('T-1 第158弾: Flutter プラグイン開発入門', 'Platform Channel + Kotlin/Swift 実装 + pub.dev 公開手順。dev.to投稿: flutter-plugin-development', '2026-04-29')
ON CONFLICT DO NOTHING;
