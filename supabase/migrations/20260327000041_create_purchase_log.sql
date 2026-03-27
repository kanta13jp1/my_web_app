-- 買い物ログ: 何を買ったか忘れない仕組み
-- レシート代わりにサッと記録 → あとで振り返り

-- 買い物セッション（1回の買い物 = 1セッション）
CREATE TABLE IF NOT EXISTS purchase_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- どこで買った
  store_name text NOT NULL DEFAULT '',
  store_category text NOT NULL DEFAULT 'convenience' CHECK (store_category IN (
    'convenience', 'supermarket', 'drugstore', 'online',
    'restaurant', 'vending', 'other'
  )),
  -- 合計金額
  total_amount int,
  -- 支払い方法
  payment_method text DEFAULT 'cash' CHECK (payment_method IN (
    'cash', 'credit', 'debit', 'qr', 'ic_card', 'other'
  )),
  -- メモ
  memo text,
  -- 衝動買いだったか
  was_impulse boolean NOT NULL DEFAULT false,
  -- 満足度 1-5
  satisfaction int CHECK (satisfaction BETWEEN 1 AND 5),
  purchased_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE purchase_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own purchase sessions"
  ON purchase_sessions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on purchase_sessions"
  ON purchase_sessions FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_purchase_sessions_user ON purchase_sessions(user_id, purchased_at DESC);

-- 買い物アイテム（セッション内の各商品）
CREATE TABLE IF NOT EXISTS purchase_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES purchase_sessions(id) ON DELETE CASCADE,
  -- 商品情報
  item_name text NOT NULL,
  category text NOT NULL DEFAULT 'other' CHECK (category IN (
    'food', 'drink', 'snack', 'daily', 'medicine',
    'clothing', 'electronics', 'book', 'hobby', 'other'
  )),
  quantity int NOT NULL DEFAULT 1,
  unit_price int,
  -- 必要だったか
  necessity text NOT NULL DEFAULT 'needed' CHECK (necessity IN (
    'essential',   -- 絶対必要
    'needed',      -- 必要
    'nice_to_have', -- あると嬉しい
    'impulse',     -- 衝動買い
    'waste'        -- 無駄だった（振り返り時に変更）
  )),
  -- 消費期限メモ（食品用）
  expiry_note text,
  -- 使い切ったか（後で振り返り用）
  consumed boolean NOT NULL DEFAULT false,
  consumed_at timestamptz,
  emoji text DEFAULT '📦',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage purchase items via sessions"
  ON purchase_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM purchase_sessions
    WHERE purchase_sessions.id = purchase_items.session_id
      AND purchase_sessions.user_id = auth.uid()
  ));
CREATE POLICY "Service role full access on purchase_items"
  ON purchase_items FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_purchase_items_session ON purchase_items(session_id);

-- よく買うものリスト（入力補完用）
CREATE TABLE IF NOT EXISTS purchase_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  category text NOT NULL DEFAULT 'other',
  typical_price int,
  typical_store text,
  emoji text DEFAULT '📦',
  use_count int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, item_name)
);

ALTER TABLE purchase_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own purchase favorites"
  ON purchase_favorites FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on purchase_favorites"
  ON purchase_favorites FOR ALL
  USING (auth.role() = 'service_role');

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '買い物ログ機能を追加',
  '買い物セッション・アイテム記録・よく買うものリスト・衝動買い判定・消費追跡機能。コンビニで何を買ったか忘れない仕組み。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
