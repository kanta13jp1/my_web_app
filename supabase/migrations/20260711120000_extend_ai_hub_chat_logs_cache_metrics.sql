-- ベンダーダイジェスト 2026-07-05 採用 #2: prompt caching KPI + cache diagnostics
-- Anthropic 応答の実測 token / cache 指標を ai_hub_chat_logs に記録する。
-- docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md §9 (KPI 監視) の受け皿。
ALTER TABLE ai_hub_chat_logs
  ADD COLUMN IF NOT EXISTS input_tokens integer,
  ADD COLUMN IF NOT EXISTS output_tokens integer,
  ADD COLUMN IF NOT EXISTS cache_read_input_tokens integer,
  ADD COLUMN IF NOT EXISTS cache_creation_input_tokens integer,
  ADD COLUMN IF NOT EXISTS cache_miss_reason text;

COMMENT ON COLUMN ai_hub_chat_logs.cache_read_input_tokens IS
  'Anthropic usage.cache_read_input_tokens (~0.1x cost)。cache hit 率 KPI の分子';
COMMENT ON COLUMN ai_hub_chat_logs.cache_creation_input_tokens IS
  'Anthropic usage.cache_creation_input_tokens (~1.25x cost)。cache write 量';
COMMENT ON COLUMN ai_hub_chat_logs.cache_miss_reason IS
  'cache diagnostics beta (cache-diagnosis-2026-04-07) の cache_miss_reason';
