-- Session 430b: habit-tracker + bookmark-manager + poll-survey + invoice-generator + contact-manager
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Habit Tracker Edge Function 追加', '習慣トラッカー。習慣定義/チェックイン/ストリーク計算/達成率/30日統計', '2026-03-31'),
  ('Bookmark Manager Edge Function 追加', 'ブックマーク管理。URL保存/フォルダ分類/タグ/検索/削除', '2026-03-31'),
  ('Poll & Survey Edge Function 追加', 'アンケート・投票。単一/複数/自由回答/結果集計/重複防止', '2026-03-31'),
  ('Invoice Generator Edge Function 追加', '請求書生成。作成/税計算/ステータス管理/クライアント集計/月次売上', '2026-03-31'),
  ('Contact Manager Edge Function 追加', '連絡先管理。CRUD/グループ分け/検索/インタラクション履歴', '2026-03-31')
ON CONFLICT DO NOTHING;
