-- 論理的意思決定ガード: 非論理的な判断を検知してブロック
-- 「30年やめられなかった煙草を今日やめる」のような感情的・非現実的な決意を
-- 冷静に検証し、実行可能な計画に変換する

-- 意思決定レコード
CREATE TABLE IF NOT EXISTS decision_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 何を決めようとしているか
  decision_statement text NOT NULL,
  -- カテゴリ
  category text NOT NULL DEFAULT 'habit' CHECK (category IN (
    'habit', 'finance', 'relationship', 'career', 'health',
    'purchase', 'commitment', 'lifestyle', 'other'
  )),
  -- ===== 論理チェック項目 (ユーザーが回答) =====
  -- 過去にこの決意をしたことがあるか
  past_attempts int DEFAULT 0,
  -- 過去の最長継続期間
  past_max_duration_days int DEFAULT 0,
  -- 今回、過去と何が違うのか
  what_is_different text,
  -- 具体的な実行計画があるか
  has_concrete_plan boolean DEFAULT false,
  execution_plan text,
  -- 失敗した時のフォールバックがあるか
  has_fallback boolean DEFAULT false,
  fallback_plan text,
  -- 段階的なステップに分解できているか
  has_incremental_steps boolean DEFAULT false,
  incremental_steps text,
  -- この決断に必要なリソース (時間/金/協力者)
  required_resources text,
  -- 期限は現実的か
  target_date date,
  is_deadline_realistic boolean,
  -- ===== MAGI判定 =====
  -- MELCHIOR (論理): 過去のデータから成功確率を分析
  melchior_analysis text,
  melchior_success_probability int CHECK (melchior_success_probability BETWEEN 0 AND 100),
  -- BALTHASAR (共感): 感情的な動機と持続性を評価
  balthasar_analysis text,
  balthasar_sustainability_score int CHECK (balthasar_sustainability_score BETWEEN 0 AND 100),
  -- CASPER (批判): 論理的矛盾と盲点を指摘
  casper_analysis text,
  casper_logical_flaws text[],
  -- 最終判定
  verdict text CHECK (verdict IN (
    'logical',          -- 論理的: 実行してよい
    'needs_revision',   -- 要修正: 計画を練り直す必要あり
    'illogical',        -- 非論理的: このままでは実行不可
    'delusional'        -- 妄想的: 現実を直視せよ
  )),
  verdict_reason text,
  -- 改善提案 (MAGIからの代替案)
  suggested_alternative text,
  suggested_steps text[],
  -- ステータス
  status text NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending',    -- チェック待ち
    'checked',    -- チェック済み
    'revised',    -- 修正済み
    'executing',  -- 実行中
    'succeeded',  -- 成功
    'failed',     -- 失敗
    'abandoned'   -- 放棄
  )),
  -- 実行結果の振り返り
  outcome_review text,
  outcome_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE decision_checks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own decision checks"
  ON decision_checks FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on decision_checks"
  ON decision_checks FOR ALL
  USING (auth.role() = 'service_role');

-- Indexes
CREATE INDEX idx_decision_checks_user ON decision_checks(user_id, created_at DESC);
CREATE INDEX idx_decision_checks_verdict ON decision_checks(user_id, verdict);
CREATE INDEX idx_decision_checks_status ON decision_checks(user_id, status);

-- 論理的思考のパターンライブラリ（よくある非論理的パターン）
CREATE TABLE IF NOT EXISTS logical_fallacy_patterns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- パターン名
  name text NOT NULL,
  name_ja text NOT NULL,
  -- 説明
  description text NOT NULL,
  -- 検出キーワード
  detection_keywords text[] NOT NULL DEFAULT '{}',
  -- 例
  example text,
  -- 対策
  countermeasure text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE logical_fallacy_patterns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read fallacy patterns"
  ON logical_fallacy_patterns FOR SELECT
  USING (true);

CREATE POLICY "Service role full access on logical_fallacy_patterns"
  ON logical_fallacy_patterns FOR ALL
  USING (auth.role() = 'service_role');

-- 初期データ: よくある非論理的パターン
INSERT INTO logical_fallacy_patterns (name, name_ja, description, detection_keywords, example, countermeasure) VALUES
('wishful_thinking', '希望的観測',
 '根拠なく「今度こそうまくいく」と思い込む',
 ARRAY['今度こそ', '気合で', '本気出せば', '今日から'],
 '30年やめられなかった煙草を「今日こそやめる」と根拠なく決意する',
 '過去N回失敗した事実を認め、過去と何が違うかを具体的に説明できなければ実行しない'),

('all_or_nothing', '全か無か思考',
 '段階的なアプローチを取らず、一気に完璧を目指す',
 ARRAY['完全に', '一切', '絶対に', '二度と'],
 '「明日から一切甘いものを食べない」と極端な目標を立てる',
 'まず1週間、量を半分にするなど段階的な目標に修正する'),

('ignoring_base_rate', '基準率無視',
 '自分だけは例外だと思い、統計的な成功率を無視する',
 ARRAY['自分は違う', '特別', '例外'],
 'ダイエットの95%が失敗するのに「自分は成功する」と根拠なく信じる',
 '統計的な成功率を調べ、成功者が何をしたかを具体的に模倣する'),

('sunk_cost_fallacy', 'サンクコスト誤謬',
 '既に投じたコストを理由に、損切りできない',
 ARRAY['ここまでやったのに', 'もったいない', '無駄にしたくない'],
 '3年付き合った相手と合わないのに「3年を無駄にしたくない」と別れられない',
 '過去のコストは回収不能。今後のコストと利益だけで判断する'),

('emotional_reasoning', '感情的推論',
 '感情を根拠に事実を判断する',
 ARRAY['なんとなく', '気がする', '直感で', '感じる'],
 '「なんとなくうまくいく気がする」で重要な決断をする',
 '感情を一旦脇に置き、データと事実だけで判断し直す'),

('planning_fallacy', '計画錯誤',
 '必要な時間・労力を過小評価する',
 ARRAY['すぐできる', '簡単に', '1日あれば', '余裕'],
 '「1ヶ月あれば英語ペラペラになれる」と過小評価する',
 '過去の類似タスクにかかった実際の時間を基準にする'),

('confirmation_bias', '確証バイアス',
 '自分に都合の良い情報だけを集める',
 ARRAY['やっぱり', '思った通り', 'ほら見ろ'],
 '投資で「この銘柄は上がる」という情報だけを集め、下がるリスクを無視する',
 '意図的に反対意見を3つ以上集めてから判断する'),

('present_bias', '現在バイアス',
 '将来の大きな利益より、今の小さな快楽を優先する',
 ARRAY['今だけ', '明日から', '最後の一回', '今日くらい'],
 '「今日だけ」と言って禁煙を破る。「明日から本気出す」',
 '「今の自分」と「未来の自分」を別人として、未来の自分への手紙を書く')
ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '論理的意思決定ガードを追加',
  'MAGI3ノード合議で非論理的な判断を検知・ブロック。8種類の論理的誤謬パターン検出、成功確率・持続性スコア算出、代替案提示機能付き。',
  '2026-03-27'
) ON CONFLICT DO NOTHING;
