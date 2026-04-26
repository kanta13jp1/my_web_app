-- Horse racing: extend horse_provider_leaderboard view with learning_score + skip accuracy
-- Adds avg_learning_score and skip_accuracy_pct columns so the leaderboard reflects
-- the full bet-type learning loop introduced in 20260426223000.

DROP VIEW IF EXISTS horse_provider_leaderboard;
CREATE VIEW horse_provider_leaderboard AS
SELECT
  provider,
  model,
  COUNT(*) AS total_predictions,
  SUM(CASE WHEN first_correct THEN 1 ELSE 0 END) AS first_hits,
  SUM(CASE WHEN trifecta_correct THEN 1 ELSE 0 END) AS trifecta_hits,
  ROUND((SUM(CASE WHEN first_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS first_hit_rate,
  ROUND((SUM(CASE WHEN trifecta_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS trifecta_hit_rate,
  ROUND(AVG(COALESCE(learning_score, 0))::numeric, 3) AS avg_learning_score,
  ROUND(
    (SUM(CASE WHEN skip_recommendation_correct IS TRUE THEN 1 ELSE 0 END)::numeric /
     NULLIF(SUM(CASE WHEN skip_recommendation_correct IS NOT NULL THEN 1 ELSE 0 END), 0)) * 100,
    2
  ) AS skip_accuracy_pct,
  SUM(CASE WHEN skip_recommendation_correct IS NOT NULL THEN 1 ELSE 0 END) AS skip_recommendations_evaluated,
  MAX(evaluated_at) AS last_evaluated_at
FROM horse_prediction_accuracy
GROUP BY provider, model
ORDER BY avg_learning_score DESC NULLS LAST, first_hit_rate DESC NULLS LAST, total_predictions DESC;

COMMENT ON VIEW horse_provider_leaderboard IS
  'AI provider ranking by horse race prediction hit rate + learning score + skip accuracy.';
