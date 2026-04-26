-- Horse racing: bet-type recommendations and learning loop
-- Adds per-ticket-type evaluation so the app can learn from results after each race day.

ALTER TABLE IF EXISTS horse_results
  ADD COLUMN IF NOT EXISTS payouts jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE IF EXISTS horse_prediction_accuracy
  ADD COLUMN IF NOT EXISTS bet_type_hits jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS recommended_hits jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS bet_type_predictions jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS learning_score numeric(6, 3);

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

COMMENT ON VIEW horse_bet_type_accuracy IS
  'Horse racing prediction hit rate by bet type: win, place, bracket quinella, quinella, wide, exacta, trio, trifecta.';

COMMENT ON VIEW horse_bet_type_provider_accuracy IS
  'Horse racing provider/model hit rate by bet type for daily learning feedback.';
