-- Win版#112: 競馬レース データ修復 (netkeiba 風 UI 表示用)
-- 問題:
--   1. race_number が全件 NULL → "1R/2R" バッジが表示されない
--   2. race_name が "レース情報(JRA)" 等の generic 値 → netkeiba と乖離
-- 原因:
--   parse_race_id() が JRA 14桁前提だが実 data は 12桁。race_num [12:14] が空文字。
-- 修正方針:
--   - race_id_ext 12 chars 共通レイアウト: YYYY(4) + ?(4) + 場(2)/月日(2) + 番号(2)
--   - 番号は両 source とも [11..12] (1-indexed = positions 11,12)
--   - race_name = "{N}R {grade}" 形式に正規化 (netkeiba 風)

-- Step 1: race_number backfill (NULL のみ)
UPDATE horse_races
SET race_number = (SUBSTRING(race_id_ext FROM 11 FOR 2))::int
WHERE race_number IS NULL
  AND race_id_ext IS NOT NULL
  AND LENGTH(race_id_ext) >= 12
  AND SUBSTRING(race_id_ext FROM 11 FOR 2) ~ '^[0-9]+$';

-- Step 2: race_name 正規化
--   "レース情報(JRA)" / "レース 0401" 等 generic 値を "{N}R {grade}" に置換
UPDATE horse_races
SET race_name = race_number::text || 'R ' || COALESCE(grade, '一般')
WHERE race_number IS NOT NULL
  AND (
    race_name = 'レース情報(JRA)'
    OR race_name = 'レース情報(NAR)'
    OR race_name LIKE 'レース %'
    OR race_name LIKE '第%レース'
  );

-- 適用件数確認用 (deploy log で見える)
DO $$
DECLARE
  v_total int;
  v_with_num int;
  v_renamed int;
BEGIN
  SELECT COUNT(*) INTO v_total FROM horse_races;
  SELECT COUNT(*) INTO v_with_num FROM horse_races WHERE race_number IS NOT NULL;
  SELECT COUNT(*) INTO v_renamed FROM horse_races WHERE race_name LIKE '%R %';
  RAISE NOTICE 'horse_races: total=%, with race_number=%, renamed=%', v_total, v_with_num, v_renamed;
END $$;
