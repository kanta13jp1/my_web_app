-- AI プロバイダー circuit breaker テーブル
-- いずれかのプロバイダーが 429/529 を返したときにここに記録する。
-- GHA ワークフローはこのテーブルを参照してスキップ判定を行う。
CREATE TABLE IF NOT EXISTS public.ai_circuit_breaker (
  provider    text        PRIMARY KEY,
  state       text        NOT NULL DEFAULT 'closed'
                          CHECK (state IN ('open', 'closed')),
  opened_at   timestamptz,
  expires_at  timestamptz,
  reason      text,
  updated_at  timestamptz DEFAULT now()
);

-- RLS 無効 (service_role のみ書き込む・anon は読み取り専用)
ALTER TABLE public.ai_circuit_breaker ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon read circuit breaker" ON public.ai_circuit_breaker
  FOR SELECT USING (true);

CREATE POLICY "service role write circuit breaker" ON public.ai_circuit_breaker
  FOR ALL USING (auth.role() = 'service_role');

-- 初期データ: 主要プロバイダーを closed 状態で挿入
INSERT INTO public.ai_circuit_breaker (provider, state) VALUES
  ('anthropic', 'closed'),
  ('openai',    'closed'),
  ('gemini',    'closed')
ON CONFLICT (provider) DO NOTHING;
