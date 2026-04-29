-- PS版#2 S86: T-1 Phase35 全4弾完結 (#167-#170) dev.to累計170本
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 第167弾: Flutter Flame ゲームエンジン', 'Component設計 + SpriteAnimation + Tiled連携 + Flutter UI統合 + Supabaseスコア管理。dev.to投稿: flutter-flame-game-engine-complete-guide', '2026-04-29'),
  ('T-1 第168弾: Supabase pg_cron スケジュールジョブ', 'cron構文 + セッションクリーンアップ + 日次レポート + EFトリガー + 実行ログ監視。dev.to投稿: supabase-pgcron-complete-guide', '2026-04-29'),
  ('T-1 第169弾: インディー開発者メールマーケティング', 'Resend × Supabase + ウェルカムシーケンス + セグメント配信 + React Email + 開封率計測。dev.to投稿: indie-dev-email-marketing-complete-guide', '2026-04-29'),
  ('T-1 第170弾: Flutter Isolate & Compute', 'compute() + Isolate.run() + SendPort/ReceivePort + Riverpod統合 + パフォーマンス計測。dev.to投稿: flutter-isolates-compute-complete-guide', '2026-04-29')
ON CONFLICT DO NOTHING;
