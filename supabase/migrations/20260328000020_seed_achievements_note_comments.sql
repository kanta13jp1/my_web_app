-- Session daily-development (2026-03-28): ノートコメント機能実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ノートコメント機能',
  'Notion風のノートコメント機能を実装。note_commentsテーブル(RLS付き)を新設。Supabase Edge Function(GET/POST/DELETE)でノート所有権チェック。NoteEditorPageのAppBarにコメントアイコンとバッジカウント表示。DraggableScrollableSheetでコメント一覧+入力UI。flutter analyze 0件維持。',
  '2026-03-28'
)
ON CONFLICT DO NOTHING;
