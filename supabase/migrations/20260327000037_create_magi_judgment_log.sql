-- MAGIシステム判定ログ: 全AI判定の3ノード合議結果を永続化
-- MELCHIOR(論理), BALTHASAR(共感), CASPER(批判) の意見と最終統合を記録

CREATE TABLE IF NOT EXISTS magi_judgment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  -- どの機能から呼ばれたか
  source_feature text NOT NULL,
  -- ユーザーの入力/質問
  user_input text,
  -- 3ノードの個別意見
  melchior_opinion text,
  melchior_model text,
  melchior_verdict text CHECK (melchior_verdict IN ('approve', 'reject', 'conditional')),
  balthasar_opinion text,
  balthasar_model text,
  balthasar_verdict text CHECK (balthasar_verdict IN ('approve', 'reject', 'conditional')),
  casper_opinion text,
  casper_model text,
  casper_verdict text CHECK (casper_verdict IN ('approve', 'reject', 'conditional')),
  -- 合議結果
  synthesis_result text,
  synthesis_model text,
  -- 最終判定: unanimous(全会一致), majority(多数決), split(割れ)
  consensus_type text CHECK (consensus_type IN ('unanimous', 'majority', 'split')),
  -- 最終判定: approve / reject / conditional
  final_verdict text CHECK (final_verdict IN ('approve', 'reject', 'conditional')),
  -- メタデータ
  total_latency_ms int,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE magi_judgment_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own magi logs"
  ON magi_judgment_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on magi_judgment_logs"
  ON magi_judgment_logs FOR ALL
  USING (auth.role() = 'service_role');

-- Indexes
CREATE INDEX idx_magi_logs_user ON magi_judgment_logs(user_id, created_at DESC);
CREATE INDEX idx_magi_logs_feature ON magi_judgment_logs(source_feature, created_at DESC);
CREATE INDEX idx_magi_logs_verdict ON magi_judgment_logs(final_verdict);

-- MAGIシステム全体設定テーブル（ユーザーごと）
CREATE TABLE IF NOT EXISTS magi_system_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  -- MAGI有効/無効
  enabled boolean NOT NULL DEFAULT true,
  -- 各ノードの役割カスタマイズ
  melchior_role text NOT NULL DEFAULT '論理・分析・データ重視',
  balthasar_role text NOT NULL DEFAULT '共感・人間理解・感情面',
  casper_role text NOT NULL DEFAULT '批判・リスク検討・反対意見',
  -- 各ノードのモデル
  melchior_model text NOT NULL DEFAULT 'gpt-4o-mini',
  balthasar_model text NOT NULL DEFAULT 'claude-sonnet-4-6',
  casper_model text NOT NULL DEFAULT 'gemini-2.5-flash',
  synthesis_model text NOT NULL DEFAULT 'claude-sonnet-4-6',
  -- 適用する機能 (空=全機能)
  enabled_features text[] DEFAULT '{}',
  -- 判定の厳格さ (1=緩い, 5=厳格)
  strictness int NOT NULL DEFAULT 3 CHECK (strictness BETWEEN 1 AND 5),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE magi_system_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own magi config"
  ON magi_system_config FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on magi_system_config"
  ON magi_system_config FOR ALL
  USING (auth.role() = 'service_role');

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'MAGIシステムをシステム全体に反映 — 判定ログ永続化 + 設定テーブル追加',
  'MELCHIOR(論理)/BALTHASAR(共感)/CASPER(批判)の3ノード合議結果をmagi_judgment_logsに永続記録。ユーザーごとのMAGI設定(magi_system_config)も追加。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
