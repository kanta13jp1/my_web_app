-- Session: カテゴリ管理・医療メモ機能追加 (2026-03-31 daily-development #5)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'カテゴリ管理機能実装',
    'メモ・タスクのカテゴリを管理するCategoriesPageを実装。Supabaseにcategoriesテーブル(RLS付き)を新設。業務メニューカタログに追加。',
    '2026-03-31'
  ),
  (
    '医療メモ機能実装',
    '服薬・通院・健康診断などの医療記録を管理するMedicalNotesPageを実装。既存notesテーブルを流用し[Medical]プレフィックスで識別。5カテゴリ対応。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
