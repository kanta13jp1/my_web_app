-- PowerShell 全体管理セッション #4 実績シード 2026-03-31

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'flutter build web --wasm ビルド成功確認 (wasm blocker完全解消)',
    'flutter build web --wasmを実行し356.7秒でビルド成功を確認。dart:html廃止・dart:js_interop移行完了済みのため追加作業なし。WebAssembly対応でランタイムパフォーマンスが向上。残課題リストから削除。',
    '2026-03-31'
  ),
  (
    'app_feedbackテーブル・FeedbackListPage管理統合・/admin-feedbackルート追加',
    'ユーザーフィードバック収集システムを構築。app_feedbackテーブルを新規作成し、FeedbackListPageで管理者がフィードバック一覧を確認・管理できるようにした。/admin-feedbackルートを追加。flutter analyze 0件維持。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
