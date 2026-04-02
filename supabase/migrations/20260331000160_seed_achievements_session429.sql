-- Session 429: file-storage + calendar + kanban + chat + automation
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('File Storage Manager Edge Function 追加', 'ファイルストレージ管理。アップロード記録/共有URL生成/プラン別容量制限/使用量追跡', '2026-03-31'),
  ('Calendar Events Edge Function 追加', 'カレンダー・イベント管理。CRUD/日週月ビュー/リマインダー/繰り返しイベント/色設定', '2026-03-31'),
  ('Kanban Board Edge Function 追加', 'カンバンボード・プロジェクト管理。ボード/カラム/カードCRUD/ドラッグ移動/ラベル/期日', '2026-03-31'),
  ('Chat Messaging Edge Function 追加', 'チャット・メッセージング。チャンネル作成/メッセージ送受信/スレッド返信/未読カウント', '2026-03-31'),
  ('Automation Workflows Edge Function 追加', 'ワークフロー自動化。IF-THENルール/5テンプレート/トリガー実行/実行ログ', '2026-03-31')
ON CONFLICT DO NOTHING;
