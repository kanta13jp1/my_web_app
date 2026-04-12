-- 競馬自動化パイプライン: レース/出走表/AI予想/結果テーブル
-- Session VSCode#64: horse racing automated pipeline

-- レーススケジュール (JRA/NAR から自動取得)
CREATE TABLE IF NOT EXISTS horse_races (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'jra',  -- 'jra' | 'nar'
  race_id_ext text,                     -- netkeiba等の外部ID (重複防止)
  race_name text NOT NULL,
  race_date date NOT NULL,
  venue text,                           -- 東京/中山/阪神 etc.
  post_time text,                       -- 発走時刻 "15:40"
  course_type text DEFAULT '芝',        -- 芝/ダート/障害
  distance integer,                     -- メートル
  grade text DEFAULT '未勝利',          -- G1/G2/G3/OP/1勝/未勝利/新馬 etc.
  num_horses integer,
  status text DEFAULT 'scheduled',      -- scheduled/completed/cancelled
  created_at timestamptz DEFAULT now(),
  UNIQUE(race_id_ext)
);

-- 出走馬テーブル
CREATE TABLE IF NOT EXISTS horse_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id uuid REFERENCES horse_races(id) ON DELETE CASCADE,
  horse_number integer,                 -- 馬番
  horse_name text NOT NULL,
  jockey text,
  trainer text,
  weight_kg numeric,                    -- 斤量
  horse_weight integer,                 -- 馬体重
  win_odds numeric,                     -- 単勝オッズ
  popularity integer,                   -- 人気順
  created_at timestamptz DEFAULT now()
);

-- AI 3連単予想テーブル
CREATE TABLE IF NOT EXISTS horse_predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id uuid REFERENCES horse_races(id) ON DELETE CASCADE,
  first_pick text NOT NULL,             -- 1着予想馬名
  second_pick text NOT NULL,            -- 2着予想馬名
  third_pick text NOT NULL,             -- 3着予想馬名
  confidence numeric DEFAULT 0.5,       -- 0.0〜1.0
  ai_reasoning text,                    -- AI の予想根拠
  ai_model text DEFAULT 'gemini',
  created_at timestamptz DEFAULT now(),
  UNIQUE(race_id)                       -- 1レースにつき1予想
);

-- 実際のレース結果テーブル
CREATE TABLE IF NOT EXISTS horse_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  race_id uuid REFERENCES horse_races(id) ON DELETE CASCADE,
  first_place text,                     -- 1着馬名
  second_place text,                    -- 2着馬名
  third_place text,                     -- 3着馬名
  trifecta_paid integer,                -- 3連単配当金 (円)
  winner_odds numeric,                  -- 1着単勝配当
  is_prediction_correct boolean,        -- AI予想の3連単的中フラグ
  fetched_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(race_id)
);

-- RLS
ALTER TABLE horse_races ENABLE ROW LEVEL SECURITY;
ALTER TABLE horse_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE horse_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE horse_results ENABLE ROW LEVEL SECURITY;

-- service_role: full access (Python fetch script + EF uses service_role)
CREATE POLICY "service_role_all_horse_races" ON horse_races FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_horse_entries" ON horse_entries FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_horse_predictions" ON horse_predictions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_horse_results" ON horse_results FOR ALL TO service_role USING (true) WITH CHECK (true);

-- authenticated: read-only (全ユーザーが閲覧可能)
CREATE POLICY "authenticated_read_horse_races" ON horse_races FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_read_horse_entries" ON horse_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_read_horse_predictions" ON horse_predictions FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_read_horse_results" ON horse_results FOR SELECT TO authenticated USING (true);

-- インデックス
CREATE INDEX IF NOT EXISTS horse_races_date_idx ON horse_races(race_date DESC);
CREATE INDEX IF NOT EXISTS horse_races_source_idx ON horse_races(source);
CREATE INDEX IF NOT EXISTS horse_entries_race_id_idx ON horse_entries(race_id);
CREATE INDEX IF NOT EXISTS horse_predictions_race_id_idx ON horse_predictions(race_id);
CREATE INDEX IF NOT EXISTS horse_results_race_id_idx ON horse_results(race_id);

-- 的中率ビュー
CREATE OR REPLACE VIEW horse_accuracy_stats AS
SELECT
  COUNT(hp.id) AS total_predictions,
  COUNT(hr.id) AS total_results,
  COUNT(CASE WHEN hr.is_prediction_correct = true THEN 1 END) AS correct_count,
  ROUND(
    COUNT(CASE WHEN hr.is_prediction_correct = true THEN 1 END)::numeric /
    NULLIF(COUNT(hr.id), 0) * 100, 1
  ) AS hit_rate_pct,
  COALESCE(SUM(CASE WHEN hr.is_prediction_correct = true THEN hr.trifecta_paid ELSE 0 END), 0) AS total_payout,
  COUNT(hr.id) * 100 AS total_stake_100,  -- 100円単位換算
  MAX(hr.trifecta_paid) AS max_payout,
  MIN(CASE WHEN hr.is_prediction_correct = true THEN hr.trifecta_paid END) AS min_payout
FROM horse_predictions hp
LEFT JOIN horse_results hr ON hp.race_id = hr.race_id;
