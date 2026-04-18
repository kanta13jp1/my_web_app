-- Horse Race Multi-Provider Ensemble Predictions (Windows版#94)
-- 目的:
-- 1) 複数 AI プロバイダーの予想を race 単位で蓄積 (既存 horse_predictions は「代表1件」として維持)
-- 2) プロバイダー別的中率を追跡 (horse_prediction_accuracy)
-- 3) provider.chat_auto (Kepion 参考) と同様に quota fallback を tools-hub predict_all で利用可能にする

CREATE TABLE IF NOT EXISTS horse_race_predictions_ensemble (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id uuid NOT NULL REFERENCES horse_races(id) ON DELETE CASCADE,
  provider text NOT NULL,
  model text NOT NULL,
  predicted_at timestamptz NOT NULL DEFAULT now(),
  first_pick text,
  second_pick text,
  third_pick text,
  confidence numeric(4, 3),
  reasoning text,
  prediction_json jsonb,
  estimated_cost_usd numeric(10, 6),
  latency_ms integer,
  UNIQUE (race_id, provider, model)
);

CREATE INDEX IF NOT EXISTS idx_ensemble_race_id ON horse_race_predictions_ensemble (race_id);
CREATE INDEX IF NOT EXISTS idx_ensemble_provider ON horse_race_predictions_ensemble (provider);
CREATE INDEX IF NOT EXISTS idx_ensemble_predicted_at ON horse_race_predictions_ensemble (predicted_at DESC);

COMMENT ON TABLE horse_race_predictions_ensemble IS 'Multi-provider predictions per race. Each (race, provider, model) is one row.';

CREATE TABLE IF NOT EXISTS horse_prediction_accuracy (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id uuid NOT NULL REFERENCES horse_races(id) ON DELETE CASCADE,
  provider text NOT NULL,
  model text NOT NULL,
  predicted_first text,
  predicted_second text,
  predicted_third text,
  actual_first text,
  actual_second text,
  actual_third text,
  first_correct boolean NOT NULL DEFAULT false,
  trifecta_correct boolean NOT NULL DEFAULT false,
  evaluated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (race_id, provider, model)
);

CREATE INDEX IF NOT EXISTS idx_accuracy_provider ON horse_prediction_accuracy (provider, model);
CREATE INDEX IF NOT EXISTS idx_accuracy_race_id ON horse_prediction_accuracy (race_id);

COMMENT ON TABLE horse_prediction_accuracy IS 'Provider-level accuracy tracking. Updated when horse_results is finalized.';

-- プロバイダー別的中率ビュー
CREATE OR REPLACE VIEW horse_provider_leaderboard AS
SELECT
  provider,
  model,
  COUNT(*) AS total_predictions,
  SUM(CASE WHEN first_correct THEN 1 ELSE 0 END) AS first_hits,
  SUM(CASE WHEN trifecta_correct THEN 1 ELSE 0 END) AS trifecta_hits,
  ROUND((SUM(CASE WHEN first_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS first_hit_rate,
  ROUND((SUM(CASE WHEN trifecta_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) AS trifecta_hit_rate,
  MAX(evaluated_at) AS last_evaluated_at
FROM horse_prediction_accuracy
GROUP BY provider, model
ORDER BY first_hit_rate DESC NULLS LAST, total_predictions DESC;

COMMENT ON VIEW horse_provider_leaderboard IS 'AI provider ranking by horse race prediction hit rate.';

-- RLS: 読み取りは誰でも可 (公開ダッシュボード用)、書き込みは service_role のみ
ALTER TABLE horse_race_predictions_ensemble ENABLE ROW LEVEL SECURITY;
ALTER TABLE horse_prediction_accuracy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ensemble_public_read" ON horse_race_predictions_ensemble;
CREATE POLICY "ensemble_public_read" ON horse_race_predictions_ensemble
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "accuracy_public_read" ON horse_prediction_accuracy;
CREATE POLICY "accuracy_public_read" ON horse_prediction_accuracy
  FOR SELECT USING (true);

-- 実績テーブルに記録
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Windows版#94: 競馬AI マルチプロバイダーアンサンブル予想基盤',
  'horse_race_predictions_ensemble + horse_prediction_accuracy + horse_provider_leaderboard view を追加。Gemini/OpenAI/Anthropic/xAI の複数モデル予想を1レース単位で蓄積しプロバイダー別的中率を追跡する。tools-hub の predict_all は fallback chain に拡張、新 action predict_ensemble / consensus を追加予定。',
  '2026-04-18'
)
ON CONFLICT DO NOTHING;
