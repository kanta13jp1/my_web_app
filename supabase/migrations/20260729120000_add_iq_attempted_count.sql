-- IQテスト: 着手した問題数を記録する
-- 作成日: 2026年7月29日
--
-- 背景 (仮説検証 H4):
--   従来は question_count (=常に25) しか持たず、
--   「3問だけ解いて時間切れ」と「25問解いて低得点」が結果上まったく区別できなかった。
--   実測では前者でも IQ 61 が算出され、低実力と判別不能になる。
--   スコアを額面どおり読んでよいかを利用者が判断できるよう、完答率の分子を持たせる。

ALTER TABLE iq_tests
  ADD COLUMN IF NOT EXISTS attempted_count INTEGER;

COMMENT ON COLUMN iq_tests.attempted_count IS
  '実際に着手した問題数。question_count との差が未回答数。NULL は列追加前の古い記録';

-- 未回答を許すため 0 も正当な値。上限だけ質問数で押さえる。
ALTER TABLE iq_tests
  DROP CONSTRAINT IF EXISTS iq_tests_attempted_count_range;

ALTER TABLE iq_tests
  ADD CONSTRAINT iq_tests_attempted_count_range
  CHECK (
    attempted_count IS NULL
    OR (attempted_count >= 0 AND attempted_count <= question_count)
  );
