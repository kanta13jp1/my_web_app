-- WBS progress update for Win #132 part 98.
--
-- Production deploy failed on the original draft because it inserted
-- the non-canonical Codex #2 instance value, which violates
-- wbs_tasks_instance_check.
-- The WBS schema tracks all Codex-owned work with the canonical instance
-- value 'codex'. Keep "Codex #2" context inside descriptions only.

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  '[AI_FLEET_SYNERGY #3] Claude Code + Codex CLI monthly changelog watch cron',
  'CX',
  'codex',
  'codex',
  'high',
  'pending',
  10,
  NULL,
  'Monthly cron to fetch Claude Code and Codex CLI changelogs, summarize with Claude API, create issues, and draft cross-instance PRs for high-impact changes. Delegated to Codex #2 in docs/cross-instance-prs/20260430_ai_tool_changelog_watch_codex2.md.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[AI_FLEET_SYNERGY #3] Claude Code + Codex CLI monthly changelog watch cron'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  '[AI_FLEET_SYNERGY #1] Instance assignment monthly audit cron',
  'CX',
  'codex',
  'codex',
  'medium',
  'pending',
  0,
  NULL,
  'Monthly audit that compares recent commits by instance against the CLAUDE.md routing matrix, then opens a GitHub issue when ownership drift is detected.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[AI_FLEET_SYNERGY #1] Instance assignment monthly audit cron'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  '[AI_FLEET_SYNERGY #4] CLAUDE.md and inject-rules monthly line-count monitor',
  'CX',
  'codex',
  'codex',
  'medium',
  'pending',
  0,
  NULL,
  'Monthly monitor for CLAUDE.md and inject-rules.txt line growth. Warn when policy files exceed the agreed pointer-based configuration thresholds.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[AI_FLEET_SYNERGY #4] CLAUDE.md and inject-rules monthly line-count monitor'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  'AI University faculty hierarchy design and 10-faculty seed',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  NULL,
  'Win part 93-97 completed the 10-faculty, 53-department hierarchy and seed structure.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'AI University faculty hierarchy design and 10-faculty seed'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  'AI University provider mapping and department seed',
  'CX',
  'ps3',
  'ps3',
  'high',
  'in_progress',
  10,
  NULL,
  'PS#3 owns provider mapping and department seeds from docs/cross-instance-prs/20260430_ai_university_faculty_department_seed_ps3.md.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'AI University provider mapping and department seed'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  'AI University four-layer drill-down UI',
  'CX',
  'vscode',
  'vscode',
  'high',
  'pending',
  0,
  NULL,
  'VSCode owns faculty, department, provider, and content drill-down UI work from docs/cross-instance-prs/20260430_ai_university_faculty_ui_vscode.md.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'AI University four-layer drill-down UI'
);

INSERT INTO wbs_tasks (
  title,
  category,
  instance,
  owner_instance,
  priority,
  status,
  progress,
  milestone_code,
  description
)
SELECT
  'AI University faculty and department actions in ai-hub',
  'CX',
  'codex',
  'codex',
  'high',
  'pending',
  0,
  NULL,
  'Codex #2 owns university.faculty_list, department_list, provider_by_department, and content_by_faculty actions without increasing the Edge Function count.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'AI University faculty and department actions in ai-hub'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 98: AI_FLEET_SYNERGY axis and WBS audit #3',
  'NotebookLM bc58b50b distilled into the AI_FLEET_SYNERGY playbook, routing rules, and delegated changelog watch work. This migration records the fleet automation dogfood update.',
  '2026-04-30'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 98: AI_FLEET_SYNERGY axis and WBS audit #3'
);
