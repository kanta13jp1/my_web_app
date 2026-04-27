-- PS#6 S66: print_learning_stats period summary + wide hit rate + race count
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'PS#6 S66 - horse racing learning stats report',
  'Enhanced print_learning_stats with period summary, evaluated race count, average score, two-day trend, evaluated_races, and wide_hit_rate_pct in GitHub summary output.',
  '2026-04-27'
WHERE NOT EXISTS (
  SELECT 1
  FROM development_achievements
  WHERE title LIKE 'PS#6 S66%'
);
