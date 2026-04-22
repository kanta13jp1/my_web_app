-- WBS Codex takeover: local election prefecture officer display.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: add prefecture chair and
-- secretary-general fields to the local election dashboard and share metadata.

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
  'AI統合',
  '🤖',
  5,
  '統一地方選 県連役員表示',
  '統一地方選700必達管理室の各県連カードに県連代表・県連幹事長・出典URLを表示し、共有ノートのメタデータにも含める',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added prefecture chair and secretary-general fields, seeded official-confirmed prefectures, and displayed officer source URLs.',
  'Completed in this slice. Next risk: remaining prefectures should be filled only after official sources are confirmed or an automated officer-source crawler is added.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 県連役員表示'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 県連役員表示',
  'Codex が統一地方選700必達管理室を改善。各県連に県連代表、県連幹事長、役員出典URLを持たせ、公式確認できた県から初期値を表示し、未確認県は公式未確認として扱うようにした。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
