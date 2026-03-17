ALTER TABLE IF EXISTS public.daily_todos
ADD COLUMN IF NOT EXISTS details text;
