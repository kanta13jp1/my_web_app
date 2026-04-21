-- Reassign open development tasks to Codex while keeping schedule automation owners intact.

UPDATE wbs_tasks
SET owner_instance = 'codex'
WHERE status <> 'completed'
  AND instance <> 'schedule'
  AND owner_instance <> 'codex';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS open development tasks reassigned to Codex',
  '未完了の開発タスク 38 件を owner_instance=codex に更新し、schedule 自動運用タスクは既存担当のまま維持した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
