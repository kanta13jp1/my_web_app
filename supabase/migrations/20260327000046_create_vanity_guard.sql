-- 見栄ガード: かっこつけない・見栄をはらない・身の丈に合わない行動を止める
-- 「金がないのに飲みに行かない」を仕組みで実現する

-- 見栄行動の記録・抑止ログ
CREATE TABLE IF NOT EXISTS vanity_guard_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 何をしようとしたか
  temptation text NOT NULL,
  -- カテゴリ
  category text NOT NULL DEFAULT 'other' CHECK (category IN (
    'drinking',        -- 金がないのに飲みに行く
    'treating',        -- 奢る余裕がないのに奢る
    'brand_goods',     -- 見栄でブランド品を買う
    'expensive_meal',  -- 身の丈に合わない食事
    'night_life',      -- キャバクラ・スナック等
    'gambling',        -- 一発逆転を狙うギャンブル
    'bragging',        -- 自慢・マウント発言
    'lying',           -- 見栄のための嘘
    'overwork',        -- 無理して引き受ける
    'gift',            -- 身の丈に合わないプレゼント
    'subscription',    -- 見栄のサブスク
    'other'
  )),
  -- いくらかかるはずだったか
  estimated_cost int DEFAULT 0,
  -- 止められたか
  resisted boolean NOT NULL DEFAULT false,
  -- 止められなかった場合の実際の出費
  actual_cost int DEFAULT 0,
  -- その時の残高 (現実直視用)
  balance_at_time int,
  -- 誰の前で見栄をはろうとしたか
  audience text,
  -- AIからの一言 (生成時に埋める)
  ai_reality_check text,
  -- 振り返りメモ
  reflection text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE vanity_guard_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own vanity guard log"
  ON vanity_guard_log FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on vanity_guard_log"
  ON vanity_guard_log FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_vanity_guard_user_date ON vanity_guard_log(user_id, created_at DESC);

-- 自分ルール (見栄をはらないための掟)
CREATE TABLE IF NOT EXISTS vanity_guard_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- ルール内容
  rule_text text NOT NULL,
  -- 例: 「残高10万円以下なら飲みに行かない」
  -- 条件タイプ
  condition_type text NOT NULL DEFAULT 'always' CHECK (condition_type IN (
    'always',           -- 常に適用
    'balance_below',    -- 残高が○円以下なら
    'debt_exists',      -- 借金がある間は
    'monthly_spent_over' -- 今月の浪費が○円超えたら
  )),
  -- 条件の閾値 (円)
  threshold int DEFAULT 0,
  -- 有効/無効
  is_active boolean NOT NULL DEFAULT true,
  -- 違反回数
  violation_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE vanity_guard_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own vanity guard rules"
  ON vanity_guard_rules FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on vanity_guard_rules"
  ON vanity_guard_rules FOR ALL
  USING (auth.role() = 'service_role');

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '見栄ガード機能を追加',
  'かっこつけない・見栄をはらない・身の丈に合わない行動を止める仕組み。誘惑の記録、抵抗/屈服ログ、自分ルール設定、残高連動の自動警告。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
