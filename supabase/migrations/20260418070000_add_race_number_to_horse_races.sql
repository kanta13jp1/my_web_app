-- horse_races にレース番号 (1R / 2R 等) を追加
-- Windowsアプリ版#82 — ユーザー要望「何レース目かわからない」

ALTER TABLE horse_races
  ADD COLUMN IF NOT EXISTS race_number integer;

-- 取得済みレコードは race_id_ext の末尾 2 桁から推定して埋める
-- JRA: 最後の2桁 / NAR: 同形式
UPDATE horse_races
SET race_number = CAST(SUBSTRING(race_id_ext FROM '[0-9]{2}$') AS integer)
WHERE race_number IS NULL
  AND race_id_ext IS NOT NULL
  AND race_id_ext ~ '[0-9]{2}$';

CREATE INDEX IF NOT EXISTS horse_races_race_number_idx ON horse_races(race_number);
