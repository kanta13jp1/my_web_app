-- PS版#2 S84: T-1 Phase33 全4弾完結 (#159-#162) dev.to累計162本
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 第159弾: Flutter Web PWA 完全ガイド', 'manifest.json + Service Worker + インストールプロンプト + FCM Push 通知。dev.to投稿: flutter-web-pwa-complete-guide', '2026-04-29'),
  ('T-1 第160弾: Supabase Storage ファイル管理', '画像アップロード + RLS + 署名付きURL + 進捗表示 + cached_network_image。dev.to投稿: supabase-storage-complete-guide', '2026-04-29'),
  ('T-1 第161弾: インディー SaaS メトリクス MRR/Churn/LTV', 'PostgreSQL ビュー + Edge Function + Flutter グリッドダッシュボード + fl_chart。dev.to投稿: indie-saas-metrics-that-matter', '2026-04-29'),
  ('T-1 第162弾: Flutter Widget & Integration テスト', 'Unit/Widget/Integration 3層 + Riverpod overrideWith + GitHub Actions CI。dev.to投稿: flutter-testing-complete-guide', '2026-04-29')
ON CONFLICT DO NOTHING;
