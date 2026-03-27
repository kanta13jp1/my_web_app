-- コンビニ経営シミュレーション: 経営判断力を実践的に鍛えるゲーム
-- 仕入れ・価格設定・人員配置・天候対応・イベント対応を通じて
-- 実際のビジネス感覚を身につける

-- プレイヤーの店舗データ
CREATE TABLE IF NOT EXISTS conveni_stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 店舗情報
  store_name text NOT NULL DEFAULT 'マイコンビニ',
  location_type text NOT NULL DEFAULT 'residential' CHECK (location_type IN (
    'residential', 'office', 'station', 'school', 'hospital', 'highway'
  )),
  -- 経営指標
  cash bigint NOT NULL DEFAULT 5000000,         -- 所持金 (初期500万円)
  total_revenue bigint NOT NULL DEFAULT 0,       -- 累計売上
  total_expense bigint NOT NULL DEFAULT 0,       -- 累計支出
  total_profit bigint NOT NULL DEFAULT 0,        -- 累計利益
  reputation int NOT NULL DEFAULT 50,            -- 評判 (0-100)
  customer_satisfaction int NOT NULL DEFAULT 50,  -- 顧客満足度 (0-100)
  -- 店舗レベル
  store_level int NOT NULL DEFAULT 1,
  experience_points int NOT NULL DEFAULT 0,
  -- ゲーム進行
  current_day int NOT NULL DEFAULT 1,
  current_season text NOT NULL DEFAULT 'spring' CHECK (current_season IN (
    'spring', 'summer', 'autumn', 'winter'
  )),
  -- スタッフ
  staff_count int NOT NULL DEFAULT 2,
  staff_morale int NOT NULL DEFAULT 70,
  -- ステータス
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE conveni_stores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own conveni stores"
  ON conveni_stores FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on conveni_stores"
  ON conveni_stores FOR ALL
  USING (auth.role() = 'service_role');

-- 商品カタログ (全プレイヤー共有)
CREATE TABLE IF NOT EXISTS conveni_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL CHECK (category IN (
    'onigiri', 'bento', 'bread', 'drink', 'snack', 'daily',
    'magazine', 'tobacco', 'alcohol', 'frozen', 'dessert', 'instant'
  )),
  base_cost int NOT NULL,       -- 仕入原価
  suggested_price int NOT NULL, -- 推奨販売価格
  shelf_life_days int NOT NULL DEFAULT 3,  -- 消費期限 (日)
  -- 需要パラメータ
  base_demand int NOT NULL DEFAULT 10,     -- 基本需要 (1日あたり)
  season_modifier jsonb DEFAULT '{"spring":1.0,"summer":1.0,"autumn":1.0,"winter":1.0}',
  weather_modifier jsonb DEFAULT '{"sunny":1.0,"cloudy":1.0,"rainy":0.8,"hot":1.0,"cold":1.0}',
  -- メタ
  emoji text DEFAULT '📦',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE conveni_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read conveni products"
  ON conveni_products FOR SELECT USING (true);
CREATE POLICY "Service role full access on conveni_products"
  ON conveni_products FOR ALL
  USING (auth.role() = 'service_role');

-- 店舗の在庫
CREATE TABLE IF NOT EXISTS conveni_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES conveni_stores(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES conveni_products(id) ON DELETE CASCADE,
  quantity int NOT NULL DEFAULT 0,
  selling_price int NOT NULL,
  ordered_on_day int NOT NULL,
  expires_on_day int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(store_id, product_id, ordered_on_day)
);

ALTER TABLE conveni_inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage inventory via stores"
  ON conveni_inventory FOR ALL
  USING (EXISTS (
    SELECT 1 FROM conveni_stores WHERE conveni_stores.id = conveni_inventory.store_id AND conveni_stores.user_id = auth.uid()
  ));
CREATE POLICY "Service role full access on conveni_inventory"
  ON conveni_inventory FOR ALL
  USING (auth.role() = 'service_role');

-- 日次経営記録
CREATE TABLE IF NOT EXISTS conveni_daily_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES conveni_stores(id) ON DELETE CASCADE,
  game_day int NOT NULL,
  -- 天候
  weather text NOT NULL DEFAULT 'sunny',
  -- イベント
  event_name text,
  event_description text,
  -- 売上
  revenue int NOT NULL DEFAULT 0,
  cost_of_goods int NOT NULL DEFAULT 0,
  staff_cost int NOT NULL DEFAULT 0,
  waste_loss int NOT NULL DEFAULT 0,   -- 廃棄ロス
  profit int NOT NULL DEFAULT 0,
  -- 来客数
  customer_count int NOT NULL DEFAULT 0,
  -- 品切れ回数
  stockout_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(store_id, game_day)
);

ALTER TABLE conveni_daily_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own daily reports"
  ON conveni_daily_reports FOR ALL
  USING (EXISTS (
    SELECT 1 FROM conveni_stores WHERE conveni_stores.id = conveni_daily_reports.store_id AND conveni_stores.user_id = auth.uid()
  ));
CREATE POLICY "Service role full access on conveni_daily_reports"
  ON conveni_daily_reports FOR ALL
  USING (auth.role() = 'service_role');

-- 初期商品データ
INSERT INTO conveni_products (name, category, base_cost, suggested_price, shelf_life_days, base_demand, emoji, sort_order) VALUES
('おにぎり (鮭)', 'onigiri', 80, 140, 2, 20, '🍙', 1),
('おにぎり (ツナマヨ)', 'onigiri', 75, 130, 2, 25, '🍙', 2),
('幕の内弁当', 'bento', 300, 498, 1, 8, '🍱', 3),
('カツ丼弁当', 'bento', 280, 450, 1, 10, '🍱', 4),
('メロンパン', 'bread', 60, 130, 3, 12, '🍞', 5),
('サンドイッチ', 'bread', 100, 250, 2, 15, '🥪', 6),
('お茶 500ml', 'drink', 50, 150, 180, 30, '🍵', 7),
('コーヒー 500ml', 'drink', 60, 160, 180, 25, '☕', 8),
('コーラ 500ml', 'drink', 55, 160, 365, 20, '🥤', 9),
('ポテトチップス', 'snack', 70, 150, 90, 10, '🍟', 10),
('チョコレート', 'snack', 80, 150, 180, 12, '🍫', 11),
('カップ麺', 'instant', 90, 200, 180, 8, '🍜', 12),
('アイスクリーム', 'frozen', 80, 180, 365, 15, '🍦', 13),
('プリン', 'dessert', 100, 200, 5, 10, '🍮', 14),
('シュークリーム', 'dessert', 80, 160, 2, 8, '🧁', 15),
('雑誌', 'magazine', 350, 500, 30, 3, '📖', 16),
('電池', 'daily', 100, 300, 3650, 2, '🔋', 17),
('ストッキング', 'daily', 150, 400, 3650, 1, '🧦', 18)
ON CONFLICT DO NOTHING;

-- アイスは夏に売れる等の季節性を更新
UPDATE conveni_products SET season_modifier = '{"spring":0.5,"summer":2.0,"autumn":0.5,"winter":0.2}'
WHERE name = 'アイスクリーム';
UPDATE conveni_products SET season_modifier = '{"spring":1.0,"summer":0.7,"autumn":1.2,"winter":1.5}'
WHERE name = 'カップ麺';
UPDATE conveni_products SET season_modifier = '{"spring":0.8,"summer":1.5,"autumn":0.8,"winter":0.5}',
  weather_modifier = '{"sunny":1.2,"cloudy":1.0,"rainy":0.6,"hot":1.8,"cold":0.3}'
WHERE name LIKE '%コーラ%';
UPDATE conveni_products SET weather_modifier = '{"sunny":0.8,"cloudy":1.0,"rainy":1.3,"hot":1.5,"cold":0.7}'
WHERE name LIKE '%コーヒー%';

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'コンビニ経営シミュレーション機能を追加',
  '仕入れ・価格設定・在庫管理・天候対応・季節性を考慮した経営シミュレーションゲーム。18種類の商品、6種類の立地、廃棄ロス管理機能付き。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
