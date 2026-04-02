-- Session 431b: payment-processor + marketplace + video-audio-manager + semantic-search + performance-review
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Payment Processor Edge Function 追加', '決済処理。支払い記録/6決済方法/履歴/年次売上レポート', '2026-03-31'),
  ('Marketplace Edge Function 追加', 'マーケットプレイス。8組込プラグイン/インストール/レビュー/カテゴリ', '2026-03-31'),
  ('Video Audio Manager Edge Function 追加', '動画・音声管理。メディア登録/プレイリスト/文字起こし/検索', '2026-03-31'),
  ('Semantic Search Edge Function 追加', 'セマンティック検索。ノート/タスク横断検索/フィルタ/保存検索/サジェスト', '2026-03-31'),
  ('Performance Review Edge Function 追加', '人事評価。OKR/KPI設定/自己評価/360度フィードバック/評価履歴', '2026-03-31')
ON CONFLICT DO NOTHING;
