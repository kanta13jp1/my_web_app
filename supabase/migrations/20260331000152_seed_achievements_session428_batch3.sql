-- Session 428 batch 3: content-moderation + api-rate-limiter + notification-preferences
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Content Moderation Edge Function 追加', 'ユーザー生成コンテンツの安全性チェック、禁止パターン検出、スパム判定、モデレーションログ', '2026-03-31'),
  ('API Rate Limiter Edge Function 追加', 'プラン別APIレートリミット管理、利用量追跡、X-RateLimit ヘッダー対応', '2026-03-31'),
  ('Notification Preferences Edge Function 追加', '通知設定管理 (9タイプ×メール/プッシュ/頻度)、デフォルト設定マージ', '2026-03-31')
ON CONFLICT DO NOTHING;
