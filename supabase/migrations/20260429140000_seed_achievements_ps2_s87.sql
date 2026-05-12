-- PS版#2 S87: T-1 Phase36 全4弾完結 (#171-#174) dev.to累計174本
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('T-1 第171弾: Flutter Web レンダリング CanvasKit vs HTML', 'レンダラー比較 + カスタム描画 + SEO対応 + PWA設定 + Web最適化。dev.to投稿: flutter-web-rendering-complete-guide', '2026-04-29'),
  ('T-1 第172弾: Supabase Realtime 完全ガイド', 'Postgres Changes + Broadcast + Presence + チャット実装 + カーソル共有。dev.to投稿: supabase-realtime-complete-guide', '2026-04-29'),
  ('T-1 第173弾: Build in Public 完全ガイド', 'Twitter/X戦略 + dev.to投稿 + 週次レポートテンプレート + Supabase指標自動集計。dev.to投稿: build-in-public-complete-guide', '2026-04-29'),
  ('T-1 第174弾: Flutter GoRouter Navigation 2.0', '認証ガード + ShellRoute + Riverpod統合 + ディープリンク + カスタム遷移。dev.to投稿: flutter-gorouter-complete-guide', '2026-04-29')
ON CONFLICT DO NOTHING;
