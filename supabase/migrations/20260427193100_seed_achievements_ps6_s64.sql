-- PS#6 S64: horse-racing-update workflow UX improvements
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'PS#6 S64 - horse-racing-update workflow UX',
  'Clarified workflow_dispatch mode options, added history/evaluate descriptions, and made stats --days configurable from workflow inputs.',
  '2026-04-27'
WHERE NOT EXISTS (
  SELECT 1
  FROM development_achievements
  WHERE title LIKE 'PS#6 S64%'
);
