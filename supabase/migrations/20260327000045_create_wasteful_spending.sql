-- 浪費トラッキング: 投資を除いた資産放出の記録
-- 資産時系列推移グラフに浪費をプロット + 種類別円グラフ

CREATE TABLE IF NOT EXISTS wasteful_spending (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 浪費カテゴリ
  category text NOT NULL CHECK (category IN (
    'alcohol',        -- 飲酒
    'tobacco',        -- 喫煙
    'cabaret',        -- キャバクラ
    'snack_bar',      -- スナック
    'girls_bar',      -- ガールズバー
    'fuzoku',         -- 風俗
    'delivery_health', -- デリヘル
    'pink_salon',     -- ピンサロ
    'sexy_cabaret',   -- セクキャバ
    'game',           -- ゲーム (課金・ゲームセンター等)
    'gambling',       -- ギャンブル (パチンコ・競馬・宝くじ等)
    'impulse_buy',    -- 衝動買い
    'junk_food',      -- ジャンクフード・コンビニ浪費
    'subscription',   -- 不要なサブスク
    'entertainment',  -- 娯楽 (映画・カラオケ等)
    'other'           -- その他
  )),
  -- 金額
  amount int NOT NULL CHECK (amount > 0),
  -- 詳細メモ
  description text,
  -- 店名
  store_name text,
  -- 支払方法
  payment_method text DEFAULT 'cash' CHECK (payment_method IN (
    'cash', 'credit', 'debit', 'qr', 'ic_card', 'other'
  )),
  -- 後悔度 1-5 (1=後悔なし, 5=とても後悔)
  regret_level int NOT NULL DEFAULT 3 CHECK (regret_level BETWEEN 1 AND 5),
  -- 衝動的だったか
  was_impulsive boolean NOT NULL DEFAULT true,
  -- 日時
  spent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE wasteful_spending ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own wasteful spending"
  ON wasteful_spending FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on wasteful_spending"
  ON wasteful_spending FOR ALL
  USING (auth.role() = 'service_role');

-- Indexes
CREATE INDEX idx_wasteful_spending_user_date ON wasteful_spending(user_id, spent_at DESC);
CREATE INDEX idx_wasteful_spending_category ON wasteful_spending(user_id, category);

-- 月次浪費サマリービュー (円グラフ用)
CREATE OR REPLACE VIEW wasteful_spending_monthly_summary AS
SELECT
  user_id,
  date_trunc('month', spent_at) AS month,
  category,
  COUNT(*) AS count,
  SUM(amount) AS total_amount,
  AVG(regret_level)::numeric(3,1) AS avg_regret
FROM wasteful_spending
GROUP BY user_id, date_trunc('month', spent_at), category;

-- カテゴリ表示名マッピング用の関数
CREATE OR REPLACE FUNCTION get_wasteful_category_label(cat text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE cat
    WHEN 'alcohol' THEN '飲酒'
    WHEN 'tobacco' THEN '喫煙'
    WHEN 'cabaret' THEN 'キャバクラ'
    WHEN 'snack_bar' THEN 'スナック'
    WHEN 'girls_bar' THEN 'ガールズバー'
    WHEN 'fuzoku' THEN '風俗'
    WHEN 'delivery_health' THEN 'デリヘル'
    WHEN 'pink_salon' THEN 'ピンサロ'
    WHEN 'sexy_cabaret' THEN 'セクキャバ'
    WHEN 'game' THEN 'ゲーム'
    WHEN 'gambling' THEN 'ギャンブル'
    WHEN 'impulse_buy' THEN '衝動買い'
    WHEN 'junk_food' THEN 'ジャンクフード'
    WHEN 'subscription' THEN '不要サブスク'
    WHEN 'entertainment' THEN '娯楽'
    WHEN 'other' THEN 'その他'
    ELSE cat
  END;
$$;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '浪費トラッキング機能を追加',
  '投資を除いた資産放出(飲酒/喫煙/風俗/ギャンブル等16カテゴリ)の記録・月次サマリー・後悔度スコア。資産時系列グラフにプロット、種類別円グラフで可視化。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
