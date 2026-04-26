-- PS#4 S70: competitors.emoji カラム追加 + original 21社 seed
-- comparison_page.dart const map から抽出 / Supabase fetch 完全化のため
-- cross-instance-pr 20260427_comparison_page_supabase_fetch.md のフォローアップ

ALTER TABLE public.competitors
  ADD COLUMN IF NOT EXISTS emoji text;  -- 'notion'→'📝' 等 1-2文字絵文字

COMMENT ON COLUMN public.competitors.emoji IS
  '競合サービスを表す絵文字。comparison_page.dart から移植。新規追加時は手動で設定。';

-- ============================================================
-- Original 21 社 emoji seed (comparison_page.dart より抽出)
-- ============================================================
UPDATE public.competitors SET emoji = '📝' WHERE id = 'notion';
UPDATE public.competitors SET emoji = '🐘' WHERE id = 'evernote';
UPDATE public.competitors SET emoji = '💰' WHERE id = 'moneyforward';
UPDATE public.competitors SET emoji = '💬' WHERE id = 'slack';
UPDATE public.competitors SET emoji = '🏢' WHERE id = 'chatwork';
UPDATE public.competitors SET emoji = '𝕏'  WHERE id = 'x';
UPDATE public.competitors SET emoji = '🎯' WHERE id = 'animaworks';
UPDATE public.competitors SET emoji = '🤖' WHERE id = 'claude-code';
UPDATE public.competitors SET emoji = '⚡' WHERE id = 'codex';
UPDATE public.competitors SET emoji = '🐎' WHERE id = 'netkeiba';
UPDATE public.competitors SET emoji = '🦾' WHERE id = 'openclaw';
UPDATE public.competitors SET emoji = '🏛️' WHERE id = 'claude-cowork';
UPDATE public.competitors SET emoji = '📋' WHERE id = 'jobcan';
UPDATE public.competitors SET emoji = '📦' WHERE id = 'amazon';
UPDATE public.competitors SET emoji = '🔍' WHERE id = 'google';
UPDATE public.competitors SET emoji = '🪟' WHERE id = 'microsoft';
UPDATE public.competitors SET emoji = '🎮' WHERE id = 'discord';
UPDATE public.competitors SET emoji = '💚' WHERE id = 'line';
UPDATE public.competitors SET emoji = '👥' WHERE id = 'facebook';
UPDATE public.competitors SET emoji = '🐙' WHERE id = 'github';
UPDATE public.competitors SET emoji = '🍽️' WHERE id = 'liven';

-- ============================================================
-- 追加: 高脅威新規競合 emoji (Phase 3 batch 追加分)
-- ============================================================
UPDATE public.competitors SET emoji = '🖱️' WHERE id = 'cursor';
UPDATE public.competitors SET emoji = '🌊' WHERE id = 'windsurf';
UPDATE public.competitors SET emoji = '🔷' WHERE id = 'v0';
UPDATE public.competitors SET emoji = '💎' WHERE id = 'obsidian';
UPDATE public.competitors SET emoji = '🧩' WHERE id = 'logseq';
UPDATE public.competitors SET emoji = '🐻' WHERE id = 'bear-app';
UPDATE public.competitors SET emoji = '🗃️' WHERE id = 'airtable';
UPDATE public.competitors SET emoji = '📄' WHERE id = 'coda';
UPDATE public.competitors SET emoji = '🔶' WHERE id = 'hubspot-crm';
UPDATE public.competitors SET emoji = '📅' WHERE id = 'calendly';
UPDATE public.competitors SET emoji = '⚡' WHERE id = 'zapier';
UPDATE public.competitors SET emoji = '🔀' WHERE id = 'n8n';
UPDATE public.competitors SET emoji = '📐' WHERE id = 'linear';
UPDATE public.competitors SET emoji = '🗂️' WHERE id = 'asana';
UPDATE public.competitors SET emoji = '📊' WHERE id = 'trello';
UPDATE public.competitors SET emoji = '✅' WHERE id = 'todoist';
UPDATE public.competitors SET emoji = '🌀' WHERE id = 'zoho-crm';
UPDATE public.competitors SET emoji = '✍️' WHERE id = 'cloudsign';
UPDATE public.competitors SET emoji = '📑' WHERE id = 'docusign';
UPDATE public.competitors SET emoji = '📈' WHERE id = 'freee';
UPDATE public.competitors SET emoji = '👔' WHERE id = 'smarthr';
UPDATE public.competitors SET emoji = '🗒️' WHERE id = 'notion-ai';
UPDATE public.competitors SET emoji = '🤖' WHERE id = 'chatgpt';
UPDATE public.competitors SET emoji = '✨' WHERE id = 'gemini';
UPDATE public.competitors SET emoji = '🔮' WHERE id = 'perplexity';

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'competitors emoji カラム追加 (PS#4 S70)',
  'comparison_page.dart const map から emoji を抽出して competitors テーブルに移植。' ||
  'original 21社 + 高脅威新規25社 計46社の emoji を設定。' ||
  'Supabase fetch 移行後も比較ページの絵文字表示が維持される。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
