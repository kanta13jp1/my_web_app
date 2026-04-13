-- Windows版#68: horse_entries に前走情報カラムを追加
-- 馬個別ページ (nar.netkeiba.com/horse/XXXX/) からスクレイピングして保存

ALTER TABLE horse_entries
  ADD COLUMN IF NOT EXISTS horse_id_ext    text,           -- netkeiba 馬ID (horse/XXXX のXXXX部分)
  ADD COLUMN IF NOT EXISTS age_sex         text,           -- 性齢 (例: 牡3, 牝4, セ5)
  ADD COLUMN IF NOT EXISTS horse_weight    integer,        -- 馬体重 (kg)
  ADD COLUMN IF NOT EXISTS horse_weight_change integer,    -- 馬体重増減 (例: +2, -4, 0)
  ADD COLUMN IF NOT EXISTS prev_finish     integer,        -- 前走着順 (1〜18 or NULL=出走なし)
  ADD COLUMN IF NOT EXISTS prev_race_name  text,           -- 前走レース名
  ADD COLUMN IF NOT EXISTS prev_race_date  date,           -- 前走日付
  ADD COLUMN IF NOT EXISTS prev_venue      text,           -- 前走場所 (例: 水沢, 大井, 東京)
  ADD COLUMN IF NOT EXISTS prev_course_type text,          -- 前走コース種別 (芝/ダート/障害/ばんえい)
  ADD COLUMN IF NOT EXISTS prev_distance   integer,        -- 前走距離 (m)
  ADD COLUMN IF NOT EXISTS prev_time       text,           -- 前走タイム (例: 1:34.5)
  ADD COLUMN IF NOT EXISTS prev_days_ago   integer;        -- 前走からの経過日数 (自動計算)

-- 馬IDでのルックアップ用インデックス
CREATE INDEX IF NOT EXISTS horse_entries_horse_id_ext_idx ON horse_entries(horse_id_ext);
