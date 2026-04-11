-- AI大学 連続学習ストリーク管理テーブル (2026-04-11)
-- ユーザーの連続学習日数を記録し、ホームカード・バッジ付与に活用する

CREATE TABLE IF NOT EXISTS ai_university_streaks (
  user_id         uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  current_streak  int NOT NULL DEFAULT 0,   -- 現在の連続学習日数
  longest_streak  int NOT NULL DEFAULT 0,   -- 過去最長記録
  last_studied_date date,                   -- 最終学習日 (JST)
  streak_updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS: ユーザーは自分のレコードのみ読み書き可能
ALTER TABLE ai_university_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_university_streaks_select_own" ON ai_university_streaks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "ai_university_streaks_upsert_own" ON ai_university_streaks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "ai_university_streaks_update_own" ON ai_university_streaks
  FOR UPDATE USING (auth.uid() = user_id);

-- ストリーク更新関数 (EF または Flutter から呼び出す)
-- 当日既に学習済みなら更新スキップ、昨日学習なら streak+1、2日以上空いたらリセット
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id uuid)
  RETURNS TABLE (current_streak int, longest_streak int, is_new_streak_day boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Tokyo')::date;
  v_rec   ai_university_streaks%ROWTYPE;
  v_new_streak int;
  v_is_new boolean := false;
BEGIN
  -- 既存レコード取得
  SELECT * INTO v_rec FROM ai_university_streaks WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    -- 初回学習
    INSERT INTO ai_university_streaks
      (user_id, current_streak, longest_streak, last_studied_date)
    VALUES (p_user_id, 1, 1, v_today);
    RETURN QUERY SELECT 1::int, 1::int, true;
    RETURN;
  END IF;

  -- 当日既に学習済みならスキップ
  IF v_rec.last_studied_date = v_today THEN
    RETURN QUERY SELECT v_rec.current_streak, v_rec.longest_streak, false;
    RETURN;
  END IF;

  v_is_new := true;

  -- 連続判定: 昨日学習していれば streak+1、それ以外はリセット
  IF v_rec.last_studied_date = v_today - 1 THEN
    v_new_streak := v_rec.current_streak + 1;
  ELSE
    v_new_streak := 1;
  END IF;

  UPDATE ai_university_streaks SET
    current_streak    = v_new_streak,
    longest_streak    = GREATEST(v_rec.longest_streak, v_new_streak),
    last_studied_date = v_today,
    streak_updated_at = now()
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT v_new_streak, GREATEST(v_rec.longest_streak, v_new_streak), v_is_new;
END;
$$;

-- インデックス: ランキング表示用 (streak 降順)
CREATE INDEX IF NOT EXISTS ai_university_streaks_streak_idx
  ON ai_university_streaks (current_streak DESC);
