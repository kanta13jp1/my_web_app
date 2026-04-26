-- Horse racing: daily learning views and stable bet-type ordering.
-- Keeps the learning loop visible after result fetch + backfill evaluation.

CREATE OR REPLACE VIEW horse_bet_type_accuracy AS
WITH evaluated AS (
  SELECT
    hpa.provider,
    hpa.model,
    hit.key AS bet_type,
    (hit.value)::boolean AS is_hit,
    hpa.evaluated_at
  FROM horse_prediction_accuracy hpa
  CROSS JOIN LATERAL jsonb_each_text(COALESCE(hpa.bet_type_hits, '{}'::jsonb)) AS hit(key, value)
)
SELECT
  bet_type,
  COUNT(*) AS total_predictions,
  SUM(CASE WHEN is_hit THEN 1 ELSE 0 END) AS hits,
  ROUND((SUM(CASE WHEN is_hit THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS hit_rate_pct,
  MAX(evaluated_at) AS last_evaluated_at
FROM evaluated
GROUP BY bet_type
ORDER BY
  CASE bet_type
    WHEN '購入しない' THEN 0
    WHEN '複勝' THEN 1
    WHEN 'ワイド' THEN 2
    WHEN '単勝' THEN 3
    WHEN '馬連' THEN 4
    WHEN '枠連' THEN 5
    WHEN '馬単' THEN 6
    WHEN '3連複' THEN 7
    WHEN '3連単' THEN 8
    ELSE 99
  END;

CREATE OR REPLACE VIEW horse_bet_type_provider_accuracy AS
WITH evaluated AS (
  SELECT
    hpa.provider,
    hpa.model,
    hit.key AS bet_type,
    (hit.value)::boolean AS is_hit,
    hpa.evaluated_at
  FROM horse_prediction_accuracy hpa
  CROSS JOIN LATERAL jsonb_each_text(COALESCE(hpa.bet_type_hits, '{}'::jsonb)) AS hit(key, value)
)
SELECT
  provider,
  model,
  bet_type,
  COUNT(*) AS total_predictions,
  SUM(CASE WHEN is_hit THEN 1 ELSE 0 END) AS hits,
  ROUND((SUM(CASE WHEN is_hit THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS hit_rate_pct,
  MAX(evaluated_at) AS last_evaluated_at
FROM evaluated
GROUP BY provider, model, bet_type
ORDER BY hit_rate_pct DESC NULLS LAST, total_predictions DESC;

CREATE OR REPLACE VIEW horse_learning_daily_accuracy AS
SELECT
  hr.race_date,
  COUNT(*) AS evaluated_predictions,
  COUNT(DISTINCT hpa.race_id) AS evaluated_races,
  ROUND(AVG(COALESCE(hpa.learning_score, 0))::numeric, 3) AS avg_learning_score,
  ROUND((SUM(CASE WHEN hpa.first_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS first_hit_rate_pct,
  ROUND((SUM(CASE WHEN hpa.trifecta_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS trifecta_hit_rate_pct,
  ROUND((SUM(CASE WHEN (hpa.bet_type_hits->>'複勝')::boolean THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS place_hit_rate_pct,
  ROUND((SUM(CASE WHEN (hpa.bet_type_hits->>'ワイド')::boolean THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS wide_hit_rate_pct,
  ROUND((SUM(CASE WHEN hpa.skip_recommendation_correct IS TRUE THEN 1 ELSE 0 END)::numeric / NULLIF(SUM(CASE WHEN hpa.skip_recommendation_correct IS NOT NULL THEN 1 ELSE 0 END), 0)) * 100, 2) AS skip_accuracy_pct,
  MAX(hpa.evaluated_at) AS last_evaluated_at
FROM horse_prediction_accuracy hpa
JOIN horse_races hr ON hr.id = hpa.race_id
GROUP BY hr.race_date
ORDER BY hr.race_date DESC;

CREATE OR REPLACE VIEW horse_learning_backfill_status AS
SELECT
  hr.race_date,
  hr.source,
  COUNT(DISTINCT hr.id) AS races,
  COUNT(DISTINCT hres.race_id) AS races_with_results,
  COUNT(DISTINCT hpe.race_id) FILTER (
    WHERE hpe.provider = 'baseline' AND hpe.model = 'low-risk-ranker-v1'
  ) AS baseline_predictions,
  COUNT(DISTINCT hpa.race_id) FILTER (
    WHERE hpa.provider = 'baseline' AND hpa.model = 'low-risk-ranker-v1'
  ) AS baseline_evaluated_races
FROM horse_races hr
LEFT JOIN horse_results hres ON hres.race_id = hr.id
LEFT JOIN horse_race_predictions_ensemble hpe ON hpe.race_id = hr.id
LEFT JOIN horse_prediction_accuracy hpa ON hpa.race_id = hr.id
GROUP BY hr.race_date, hr.source
ORDER BY hr.race_date DESC, hr.source;

COMMENT ON VIEW horse_learning_daily_accuracy IS
  'Daily horse-racing learning score and hit-rate trend after result evaluation.';

COMMENT ON VIEW horse_learning_backfill_status IS
  'Coverage of historical low-risk baseline predictions used to accumulate learning data.';
