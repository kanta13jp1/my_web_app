-- This script creates a new table 'someday_tasks' for the "stock" feature.
-- Please run this in your Supabase SQL Editor.
-- This is a new table, so it will not interfere with any existing 'tasks' table.

CREATE TABLE public.someday_tasks (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  user_id uuid DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  task text NOT NULL,
  is_completed boolean DEFAULT false NOT NULL,
  is_important boolean DEFAULT false NOT NULL,
  details text,
  category text,
  estimated_minutes integer,
  difficulty text
);

-- Add comments for clarity
COMMENT ON TABLE public.someday_tasks IS 'Stores tasks that the user wants to do someday but not today.';
COMMENT ON COLUMN public.someday_tasks.user_id IS 'The user this task belongs to.';
COMMENT ON COLUMN public.someday_tasks.task IS 'The content of the task.';

-- Enable Row Level Security (RLS) for the new table
ALTER TABLE public.someday_tasks ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
CREATE POLICY "Enable read access for users based on user_id"
ON public.someday_tasks FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Enable insert for users based on user_id"
ON public.someday_tasks FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update for users based on user_id"
ON public.someday_tasks FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Enable delete for users based on user_id"
ON public.someday_tasks FOR DELETE USING (auth.uid() = user_id);
