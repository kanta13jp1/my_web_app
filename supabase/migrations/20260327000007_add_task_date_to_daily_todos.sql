-- daily_todos テーブルに task_date カラムを追加
-- カレンダービューでタスクを日付ごとに表示するために必要
-- 既存のタスクには created_at の日付部分をデフォルトとして設定

ALTER TABLE daily_todos
  ADD COLUMN IF NOT EXISTS task_date date;

-- 既存レコードに task_date を設定 (created_at の日付部分)
UPDATE daily_todos
SET task_date = (created_at AT TIME ZONE 'Asia/Tokyo')::date
WHERE task_date IS NULL AND created_at IS NOT NULL;

-- 今後の INSERT でデフォルト値を今日の日付にする
ALTER TABLE daily_todos
  ALTER COLUMN task_date SET DEFAULT CURRENT_DATE;

-- task_date でのクエリを高速化するインデックス
CREATE INDEX IF NOT EXISTS idx_daily_todos_task_date
  ON daily_todos (task_date);

COMMENT ON COLUMN daily_todos.task_date IS 'タスクの対象日 (カレンダービュー表示用)';
