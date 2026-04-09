-- Windows版: 機能#12 コンソールエラー自動フィードバック投稿
-- feature_requests テーブルに is_auto_reported カラムを追加
ALTER TABLE feature_requests
  ADD COLUMN IF NOT EXISTS is_auto_reported boolean DEFAULT false;

COMMENT ON COLUMN feature_requests.is_auto_reported IS 'FlutterError.onError 経由で自動投稿されたフィードバックの場合 true';
