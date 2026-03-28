-- memo_reactions: Anonymous emoji reactions on public memos
-- Dedup by (memo_id, ip_hash, reaction_type) — one reaction per type per visitor

CREATE TABLE IF NOT EXISTS memo_reactions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id     integer     NOT NULL REFERENCES public_memos(id) ON DELETE CASCADE,
  reaction    text        NOT NULL CHECK (reaction IN ('👍','❤️','🔥','💡','🎉')),
  ip_hash     text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Prevent duplicate reactions (same visitor, same memo, same emoji)
CREATE UNIQUE INDEX IF NOT EXISTS memo_reactions_dedup
  ON memo_reactions (memo_id, ip_hash, reaction);

-- Fast aggregation by memo
CREATE INDEX IF NOT EXISTS memo_reactions_memo_id_idx ON memo_reactions (memo_id);

-- RLS
ALTER TABLE memo_reactions ENABLE ROW LEVEL SECURITY;

-- Anyone can read reaction counts
CREATE POLICY "memo_reactions_select" ON memo_reactions
  FOR SELECT USING (true);

-- Anyone can insert (anon or auth) — dedup enforced by unique index
CREATE POLICY "memo_reactions_insert" ON memo_reactions
  FOR INSERT WITH CHECK (true);
