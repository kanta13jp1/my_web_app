-- Codex takeover: local-election latest fetch timeout recovery.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: restore production
-- dashboard refresh reliability after local-election-intelligence started
-- timing out when the optional AI summary was requested.

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
  'AI統合',
  '🤖',
  5,
  '統一地方選 最新取得タイムアウト復旧',
  '統一地方選700必達管理室の最新取得で、通常ダッシュボード更新はAI要約なしで実態データを取得し、Flutter側の待機時間を90秒へ延長。local-election-intelligence のOpenAI要約は6秒でフォールバックし、外部公式サイト取得が遅い日でも本体データを返しやすくする。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'alpha',
  'high',
  'Done 2026-04-23: Codex reproduced the production failure path, made dashboard refresh skip optional AI summaries, extended the client timeout, added an OpenAI fallback timeout, and verified Flutter + Deno checks.',
  'Next: split slow official-site scraping into cached background sync and a fast read endpoint if refresh latency remains above 30 seconds.',
  0.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 最新取得タイムアウト復旧'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 最新取得タイムアウト復旧',
  'Codex restored reliability for the local-election dashboard latest refresh by avoiding optional AI summary work on the UI refresh path, extending the Flutter Edge Function timeout, and adding a bounded OpenAI fallback inside local-election-intelligence.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
