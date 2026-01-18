-- todos table
CREATE TABLE todos (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task text NOT NULL,
    is_completed boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    due_date date NOT NULL
);

-- RLS
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow select access to own todos" ON todos
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Allow insert access to own todos" ON todos
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow update access to own todos" ON todos
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Allow delete access to own todos" ON todos
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_todos_user_id_due_date ON todos(user_id, due_date);
