-- Session 432n: Edge Functions 175→180 (email-template, sitemap, 2fa, changelog, access-control)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('email-template-builder Edge Function', 'メールテンプレートビルダー機能 — テンプレート作成・変数置換・プレビュー・キャンペーン記録・開封率/クリック率分析 (Mailchimp/SendGrid競合)', '2026-04-01'),
  ('sitemap-analytics Edge Function', 'Web分析機能 — ページビュー記録・リファラー分析・デバイス/ブラウザ分析・コンバージョントラッキング (Google Analytics競合)', '2026-04-01'),
  ('two-factor-auth Edge Function', '二要素認証管理機能 — TOTP設定・バックアップコード生成・デバイス信頼・認証ログ・セキュリティ設定 (Google/Microsoft/GitHub競合)', '2026-04-01'),
  ('changelog-manager Edge Function', 'チェンジログ・リリースノート管理機能 — リリース作成・変更点カテゴリ分類・Markdown自動生成・公開管理 (GitHub Releases競合)', '2026-04-01'),
  ('access-control Edge Function', 'アクセス制御・権限管理機能 — ロール管理・リソースアクセス制御・招待管理・アクセスログ (Google Workspace/Microsoft 365競合)', '2026-04-01')
ON CONFLICT DO NOTHING;
