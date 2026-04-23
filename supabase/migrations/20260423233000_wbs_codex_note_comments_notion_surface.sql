-- WBS Codex continuation: apply NotebookLM learnings to note comments.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: turn the existing note
-- comment feature into a more Notion-like reusable surface with shared UI,
-- correct badge counts, author identity, and realtime refresh.

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS estimated_hours numeric DEFAULT 0;

INSERT INTO wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'コアSaaS開発',
  '📝',
  4,
  'ノートコメント Notion風再利用Realtime',
  'NotebookLM のコメント実装知見を本プロジェクトへ適用し、ノートコメントを共通UIへ統合する。Note Editor と /note-comments を同じコメント面へ寄せ、全件バッジ、表示名、リアルタイム更新、テストを追加する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a reusable note comment service and shared panel, corrected note comment badge counts to reflect all visible comments, exposed author identity, and wired realtime refresh into the note editor and standalone note-comments page.',
  'Next: extend the same reusable comment surface to public memo and future collaborative note contexts so threaded discussion can share one implementation path.',
  1.2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ノートコメント Notion風再利用Realtime'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ノートコメント Notion風再利用Realtime',
  'Codex applied the NotebookLM comment implementation learnings to the existing note comment feature by introducing a shared panel, author identity, correct all-comment badge counts, and realtime refresh.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
