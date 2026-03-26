-- 日用品買い物リマインダー機能
-- 箱ティッシュ、コーヒー、調味料など定期的に必要なものを管理

CREATE TABLE IF NOT EXISTS shopping_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'daily',
  quantity int DEFAULT 1,
  unit text,
  estimated_price int,
  shop text,
  is_recurring boolean NOT NULL DEFAULT false,
  recurring_days int,
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('urgent', 'high', 'normal', 'low')),
  is_purchased boolean NOT NULL DEFAULT false,
  purchased_at timestamptz,
  last_purchased_at timestamptz,
  next_remind_date date,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE shopping_items IS '日用品買い物リスト';
COMMENT ON COLUMN shopping_items.category IS 'daily=日用品, food=食品, drink=飲料, seasoning=調味料, cleaning=掃除, health=健康, pet=ペット, other=その他';
COMMENT ON COLUMN shopping_items.recurring_days IS '定期購入の場合の間隔(日数)。例: ティッシュ30日、コーヒー14日';
COMMENT ON COLUMN shopping_items.next_remind_date IS '次のリマインド日。購入完了時に recurring_days 後に自動設定';

-- 買い物履歴ログ
CREATE TABLE IF NOT EXISTS shopping_purchase_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  item_id uuid REFERENCES shopping_items(id) ON DELETE CASCADE,
  purchased_at timestamptz NOT NULL DEFAULT now(),
  actual_price int,
  shop text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE shopping_purchase_logs IS '買い物履歴ログ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_shopping_items_user
  ON shopping_items (user_id, is_purchased);

CREATE INDEX IF NOT EXISTS idx_shopping_items_remind
  ON shopping_items (user_id, next_remind_date)
  WHERE is_recurring = true AND is_purchased = false;

CREATE INDEX IF NOT EXISTS idx_shopping_purchase_logs_item
  ON shopping_purchase_logs (item_id, purchased_at DESC);

-- RLS
ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_purchase_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_shopping_items"
  ON shopping_items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_shopping_logs"
  ON shopping_purchase_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_shopping_items"
  ON shopping_items FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "service_role_shopping_logs"
  ON shopping_purchase_logs FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
