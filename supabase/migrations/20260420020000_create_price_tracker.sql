-- Price Tracker: 商品 wishlist + 価格推移トラッキング
-- NotebookLM "Building a Zero-Cost Amazon Price Tracker" (d6dd44af) を本プロジェクトに統合
-- (Win版#131 セッション 2026-04-20)
--
-- 既存資産との関係:
--   - shopping_items: 日用品リマインダー (price/URL なし)
--   - purchase_sessions: 購入後のログ (事前 wishlist なし)
--   - wasteful_spending: 浪費トラッキング (時系列価格データなし)
--   - tracked_products: 「目標価格 + URL + 価格推移」を持つ wishlist (本 migration で新規)

-- ============================================================
-- 1. tracked_products: 価格追跡対象商品 (wishlist)
-- ============================================================
CREATE TABLE IF NOT EXISTS tracked_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 商品情報
  product_url text NOT NULL,
  product_name text NOT NULL DEFAULT '',
  store_domain text NOT NULL DEFAULT '',  -- amazon.co.jp / rakuten.co.jp / yahoo.co.jp など
  image_url text,
  -- 価格目標
  current_price int,                       -- 最新取得価格 (yen)
  target_price int,                        -- ユーザー設定の目標価格 (この価格以下で通知)
  highest_price int,                       -- 観測史上最高
  lowest_price int,                        -- 観測史上最安 (買い時判断用)
  -- 通知制御
  notify_on_drop boolean NOT NULL DEFAULT true,
  notified_at timestamptz,                 -- 直近通知時刻 (重複通知防止)
  -- メモ
  note text DEFAULT '',
  -- ライフサイクル
  is_active boolean NOT NULL DEFAULT true, -- false = ユーザーが追跡停止
  is_purchased boolean NOT NULL DEFAULT false, -- 購入済み
  purchased_at timestamptz,
  purchased_price int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- 1 ユーザーが同一 URL を複数回追加するのは無意味
  UNIQUE (user_id, product_url)
);

ALTER TABLE tracked_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own tracked products"
  ON tracked_products FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on tracked_products"
  ON tracked_products FOR ALL
  USING (auth.role() = 'service_role');

CREATE INDEX idx_tracked_products_user_active
  ON tracked_products(user_id, is_active, updated_at DESC);

CREATE INDEX idx_tracked_products_active
  ON tracked_products(is_active)
  WHERE is_active = true AND is_purchased = false;

COMMENT ON TABLE tracked_products IS '価格追跡対象商品 (wishlist + price target)';
COMMENT ON COLUMN tracked_products.target_price IS 'ユーザー設定の目標価格。current_price がこれ以下になったら notify_on_drop=true なら通知';
COMMENT ON COLUMN tracked_products.lowest_price IS '観測史上最安値。「本日の最安値≠史上最安値」という事実をユーザーが確認できる';

-- ============================================================
-- 2. price_logs: 価格推移時系列データ
-- ============================================================
CREATE TABLE IF NOT EXISTS price_logs (
  id bigserial PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES tracked_products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 取得値
  price int NOT NULL,
  in_stock boolean NOT NULL DEFAULT true,
  source text NOT NULL DEFAULT 'manual'
    CHECK (source IN ('manual', 'scraper', 'api', 'browser_extension')),
  fetched_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE price_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own price logs"
  ON price_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own price logs"
  ON price_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on price_logs"
  ON price_logs FOR ALL
  USING (auth.role() = 'service_role');

-- 時系列クエリ最適化 (チャート表示で頻用)
CREATE INDEX idx_price_logs_product_time
  ON price_logs(product_id, fetched_at DESC);

CREATE INDEX idx_price_logs_user_time
  ON price_logs(user_id, fetched_at DESC);

COMMENT ON TABLE price_logs IS '価格推移時系列データ (チャート表示・最安値検出用)';
COMMENT ON COLUMN price_logs.source IS 'manual=ユーザー手動入力 / scraper=Edge Function 自動取得 / api=公式API / browser_extension=将来';

-- ============================================================
-- 3. trigger: price_logs INSERT で tracked_products を自動更新
-- ============================================================
CREATE OR REPLACE FUNCTION update_tracked_product_on_price_log()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE tracked_products
  SET
    current_price = NEW.price,
    highest_price = GREATEST(COALESCE(highest_price, NEW.price), NEW.price),
    lowest_price = LEAST(COALESCE(lowest_price, NEW.price), NEW.price),
    updated_at = NEW.fetched_at
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_price_logs_update_product ON price_logs;
CREATE TRIGGER trg_price_logs_update_product
  AFTER INSERT ON price_logs
  FOR EACH ROW
  EXECUTE FUNCTION update_tracked_product_on_price_log();

-- ============================================================
-- 4. development_achievements への記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '価格トラッカー機能 — 商品 URL を貼り付けて目標価格まで自動追跡',
  'tracked_products + price_logs テーブルを追加。Amazon/楽天/Yahoo など EC サイトの URL を登録 → 価格推移を蓄積 → 目標価格達成で通知。NotebookLM "Building a Zero-Cost Amazon Price Tracker" (d6dd44af) の知見を統合 (Win版#131)。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
