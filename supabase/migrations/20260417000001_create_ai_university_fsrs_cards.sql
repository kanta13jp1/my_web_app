-- P1: FSRS スペース反復カード (AI大学 v2)
CREATE TABLE IF NOT EXISTS ai_university_fsrs_cards (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES auth.users NOT NULL,
  provider     text NOT NULL,
  question_id  text NOT NULL,
  due_date     timestamptz NOT NULL DEFAULT now(),
  stability    float NOT NULL DEFAULT 1.0,
  difficulty   float NOT NULL DEFAULT 0.3,
  state        text NOT NULL DEFAULT 'new',
  reps         int NOT NULL DEFAULT 0,
  lapses       int NOT NULL DEFAULT 0,
  last_review  timestamptz,
  UNIQUE(user_id, provider, question_id)
);

ALTER TABLE ai_university_fsrs_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_fsrs_cards" ON ai_university_fsrs_cards
  FOR ALL USING (user_id = auth.uid());

CREATE INDEX idx_fsrs_cards_due ON ai_university_fsrs_cards (user_id, provider, due_date);
