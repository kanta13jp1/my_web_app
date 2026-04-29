-- VSCode S20: AIアシストダイアログ「ノートに保存」ボタン追加 (#975 Phase 1)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'feat(ux): AIアシストダイアログ ノートに保存ボタン (#975)',
  'user_tasks_page.dart の _AiAssistDialog に「ノートに保存」OutlinedButton を追加。AIの見立て/サブタスク/手順/チェックリストを Markdown 整形し tools-hub note.add で quick_note に永続保存。breakdown / procedure 両モード対応。tags: ai-assist + モード識別。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
