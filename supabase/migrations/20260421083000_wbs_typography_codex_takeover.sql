-- Codex takeover: typography unification guardrails.
--
-- Only the typography task Codex actually started is moved to the Codex owner.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 65),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added ThemeService typography regression tests that lock Japanese body line-height at 1.7+, small body at 1.6+, labels at 1.5+, and the NotoSansJP font family/fallbacks for light and dark themes.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'Next: audit hard-coded TextStyle(height:) overrides on high-traffic pages and migrate them to Theme.of(context).textTheme where practical.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'タイポグラフィ統一 (line-height 1.7+)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Typography line-height guardrails Codex takeover',
  'Codex が タイポグラフィ統一 (line-height 1.7+) を一時引き継ぎ、ThemeService の light/dark 両テーマで日本語本文 line-height 1.7+、補助本文 1.6+、label 1.5+、NotoSansJP font family/fallback を検証する回帰テストを追加。WBS owner を Codex に変更し、進捗を 65% に更新した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
