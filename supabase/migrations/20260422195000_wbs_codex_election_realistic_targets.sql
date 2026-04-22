-- WBS Codex takeover: realistic local-election prefecture targets.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: recalibrate prefecture KGI
-- targets so incumbent retention starts from actual incumbents and newcomer
-- win targets are based on incumbent scale, with only small situational
-- foothold adjustments for zero-incumbent prefectures.

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
  '統一地方選 県連別現実目標再調整',
  '県連別KGI/KPIの現職維持目標を実際の現職数に合わせ、新人当選目標は現職数を基準に全体700人到達へ補正する。現職0県は予定選挙や候補確認がある場合のみ小さな足場目標に留める。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex recalibrated local-election auto target allocation. Incumbent retention now equals current incumbents, newcomer win targets are based on incumbent scale and fit the 700 total, and zero-incumbent prefectures no longer inherit unrealistic retention/newcomer targets.',
  'Next: review real production snapshot after the next local-election-intelligence sync and tune any prefecture-specific exceptions with official context.',
  1
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 県連別現実目標再調整'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex corrected KGI/KPI target allocation so current incumbents drive retention targets and newcomer win targets.',
  recovery_plan = 'Next: validate prefecture-specific exceptions after the next official data refresh.'
WHERE title = '統一地方選 KGI/CSF/KPI設計';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 県連別現実目標再調整',
  'Codex adjusted prefecture-level local-election KGI/KPI generation. The plan now uses actual current incumbents as incumbent retention targets, sets newcomer win targets from incumbent scale, preserves the overall 700-person KGI when complete prefecture data is available, and keeps zero-incumbent prefectures to small foothold targets instead of unrealistic allocations.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
