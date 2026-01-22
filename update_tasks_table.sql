-- This script updates the 'tasks' table to include columns needed for the "stock" feature.
-- Please run this in your Supabase SQL Editor.

-- Add columns to the 'tasks' table if they don't exist.
-- This makes the 'tasks' table schema compatible with 'daily_todos'.
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS is_completed boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_important boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS details text,
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS estimated_minutes integer,
  ADD COLUMN IF NOT EXISTS difficulty text,
  ADD COLUMN IF NOT EXISTS user_id uuid DEFAULT auth.uid();

-- The following commands set these new columns to be NOT NULL.
-- This might fail if you have existing data in the 'tasks' table where these columns would be null.
-- If it fails, you may need to manually clean up old data.
ALTER TABLE public.tasks ALTER COLUMN is_completed SET NOT NULL;
ALTER TABLE public.tasks ALTER COLUMN is_important SET NOT NULL;


-- Enable Row Level Security (RLS) on the 'tasks' table.
-- This is a crucial security measure to ensure users can only access their own tasks.
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts.
DROP POLICY IF EXISTS "Enable read access for users based on user_id" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.tasks;

-- Create policies to control access.
CREATE POLICY "Enable read access for users based on user_id"
ON public.tasks FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Enable insert for users based on user_id"
ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update for users based on user_id"
ON public.tasks FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Enable delete for users based on user_id"
ON public.tasks FOR DELETE USING (auth.uid() = user_id);
