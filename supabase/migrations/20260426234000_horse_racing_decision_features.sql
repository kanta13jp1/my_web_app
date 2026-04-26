-- Horse racing: skip-purchase decision, richer race features, and learning metadata.

ALTER TABLE IF EXISTS horse_entries
  ADD COLUMN IF NOT EXISTS stable text,
  ADD COLUMN IF NOT EXISTS sire text,
  ADD COLUMN IF NOT EXISTS dam text,
  ADD COLUMN IF NOT EXISTS damsire text,
  ADD COLUMN IF NOT EXISTS prev_margin text,
  ADD COLUMN IF NOT EXISTS prev_corner text,
  ADD COLUMN IF NOT EXISTS prev_last_3f numeric,
  ADD COLUMN IF NOT EXISTS best_time text,
  ADD COLUMN IF NOT EXISTS data_quality_score numeric(5, 3),
  ADD COLUMN IF NOT EXISTS odds_updated_at timestamptz;

ALTER TABLE IF EXISTS horse_prediction_accuracy
  ADD COLUMN IF NOT EXISTS skip_recommendation_correct boolean,
  ADD COLUMN IF NOT EXISTS evaluated_features jsonb NOT NULL DEFAULT '{}'::jsonb;

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

COMMENT ON COLUMN horse_prediction_accuracy.skip_recommendation_correct IS
  'Whether the AI skip-purchase recommendation avoided a low-risk core miss.';

COMMENT ON COLUMN horse_prediction_accuracy.evaluated_features IS
  'Feature set and data-quality snapshot used when evaluating the prediction.';
