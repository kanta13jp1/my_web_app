-- PS#6 S63: data quality score sync scraper <-> EF
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'PS#6 S63 - data quality score sync Scraper/EF',
  'Aligned fetch_horse_racing.py _data_quality_score with tools-hub horseRaceDataQualityScore across 15 fields. Added prev_last_3f and horse_weight_change on both sides so scraped data quality scores work as sort tie breakers.',
  '2026-04-27'
WHERE NOT EXISTS (
  SELECT 1
  FROM development_achievements
  WHERE title LIKE 'PS#6 S63%'
);
