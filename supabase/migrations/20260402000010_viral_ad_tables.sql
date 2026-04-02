-- Session 432o (VSCode): viral growth tables
-- バイラル広告生成履歴・招待コード・シェアトラッキング

-- 動画/画像広告生成履歴
CREATE TABLE IF NOT EXISTS viral_ad_generations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key text NOT NULL,
  lang text NOT NULL DEFAULT 'ja',
  type text NOT NULL DEFAULT 'image',
  script jsonb,
  caption text,
  image_prompt text,
  generated_image_url text,
  fal_job_id text,
  hashtags jsonb,
  status text NOT NULL DEFAULT 'draft',
  posted_tweet_id text,
  posted_tweet_url text,
  posted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_viral_ad_generations_template ON viral_ad_generations(template_key);
CREATE INDEX IF NOT EXISTS idx_viral_ad_generations_status ON viral_ad_generations(status);
CREATE INDEX IF NOT EXISTS idx_viral_ad_generations_created_at ON viral_ad_generations(created_at DESC);

-- 招待コード管理
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  code text NOT NULL UNIQUE,
  invite_url text NOT NULL,
  used_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(user_id);

-- 招待経由登録トラッキング
CREATE TABLE IF NOT EXISTS referral_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id text NOT NULL,
  referred_user_id text NOT NULL,
  referral_code text NOT NULL,
  registered_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_referral_tracking_referrer ON referral_tracking(referrer_user_id);

-- 開発実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('バイラル動画広告生成パイプライン実装', 'viral-video-ad-generator: Dark War風テンプレート4種、FAL.ai連携、広告スクリプト自動生成', '2026-04-02'),
  ('X メディア投稿機能実装 (画像/動画)', 'x-media-post: X API v1.1 チャンク分割アップロード + v2ツイート投稿', '2026-04-02'),
  ('バイラル成長エンジン実装', 'viral-growth-engine: 招待コード、リーダーボード、A/Bテスト、最適投稿時間制御', '2026-04-02')
ON CONFLICT DO NOTHING;
