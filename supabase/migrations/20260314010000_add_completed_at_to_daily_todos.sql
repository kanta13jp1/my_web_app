ALTER TABLE IF EXISTS public.daily_todos
ADD COLUMN IF NOT EXISTS completed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_daily_todos_completed_at
ON public.daily_todos (completed_at DESC);
