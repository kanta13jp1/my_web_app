-- growth_plans に UNIQUE 制約を追加し、21競合+短中長期 全24プランをupsert
-- DBが旧版(14社/16プラン)の場合でも Discord/LINE/Facebook/Liven/GitHub/Google/Microsoft が追加される

-- label に UNIQUE 制約 (存在しない場合のみ追加)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.growth_plans'::regclass
      AND contype = 'u'
      AND conname = 'growth_plans_label_key'
  ) THEN
    ALTER TABLE public.growth_plans ADD CONSTRAINT growth_plans_label_key UNIQUE (label);
  END IF;
END $$;

-- 全24プランをupsert (label重複時は deadline/target/features_done/features_total を更新)
INSERT INTO public.growth_plans (label, deadline, target, features_done, features_total)
VALUES
  -- 短中長期
  ('短期計画',   '2026年06月30日',          100,  0,  50),
  ('中期計画',   '2026年12月31日',         1000,  0, 200),
  ('長期計画',   '2027年12月31日',        10000,  0, 500),
  -- 競合21社 (target は上回るべきユーザー数)
  ('vs Animaworks',    '2027年12月31日',      500000,  16,  20),
  ('vs Claude Code',   '2027年12月31日',      500000,  13,  18),
  ('vs Claude Cowork', '2027年12月31日',      500000,  13,  20),
  ('vs ジョブカン',    '2028年06月30日',     5000000,   7,  20),
  ('vs Chatwork',      '2028年12月31日',     6000000,  11,  22),
  ('vs Codex',         '2028年06月30日',     1000000,  11,  16),
  ('vs OpenClaw',      '2028年06月30日',     1000000,  11,  18),
  ('vs netkeiba',      '2029年12月31日',    17000000,   8,  24),
  ('vs MoneyForward',  '2030年12月31日',    15000000,   9,  22),
  ('vs EverNote',      '2032年12月31日',   250000000,  11,  26),
  ('vs NOTION',        '2033年12月31日',   100000000,  14,  32),
  ('vs Slack',         '2034年12月31日',    65000000,   9,  28),
  ('vs X',             '2036年12月31日',   600000000,  13,  24),
  ('vs Amazon',        '2038年12月31日',   310000000,   5,  30),
  ('vs Discord',       '2035年12月31日',   200000000,   6,  26),
  ('vs LINE',          '2035年12月31日',   196000000,   4,  28),
  ('vs Facebook',      '2040年12月31日',  3070000000,   5,  30),
  ('vs Liven',         '2028年06月30日',    1000000,   10,  16),
  ('vs GitHub',        '2037年12月31日',   100000000,   8,  28),
  ('vs Google',        '2045年12月31日',  4300000000,   4,  32),
  ('vs Microsoft',     '2042年12月31日',  1500000000,   5,  30)
ON CONFLICT (label) DO UPDATE SET
  deadline       = EXCLUDED.deadline,
  target         = EXCLUDED.target,
  features_done  = EXCLUDED.features_done,
  features_total = EXCLUDED.features_total;
