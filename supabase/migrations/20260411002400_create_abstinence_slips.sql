-- abstinence_slips テーブル: 思考妨害 slip 記録 (THOUGHT_INTERRUPT_ELIMINATOR_DESIGN.md)
CREATE TABLE IF NOT EXISTS abstinence_slips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  item_id text NOT NULL,        -- AbstinenceGuardStore.items[].id
  slipped_at timestamptz NOT NULL DEFAULT now(),
  context text,                 -- どういう状況か (任意)
  trigger_note text,            -- 何がトリガーだったか (任意)
  created_at timestamptz DEFAULT now()
);

-- インデックス: ユーザーごとの時系列分析用
CREATE INDEX IF NOT EXISTS abstinence_slips_user_slipped_idx
  ON abstinence_slips (user_id, slipped_at DESC);

CREATE INDEX IF NOT EXISTS abstinence_slips_user_item_idx
  ON abstinence_slips (user_id, item_id);

-- RLS 有効化
ALTER TABLE abstinence_slips ENABLE ROW LEVEL SECURITY;

-- 自分のデータのみ操作可
CREATE POLICY "abstinence_slips_select_own" ON abstinence_slips
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "abstinence_slips_insert_own" ON abstinence_slips
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "abstinence_slips_delete_own" ON abstinence_slips
  FOR DELETE USING (auth.uid() = user_id);

-- updated_at は不要 (slip は immutable なイベントとして記録)
