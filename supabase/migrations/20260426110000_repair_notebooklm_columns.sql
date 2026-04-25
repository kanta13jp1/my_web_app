-- PS#2 S31: repair 20260425231500 で未適用の可能性がある notebooklm カラムを安全に追加
-- 原因: 231500 migration が CREATE POLICY で失敗し ALTER TABLE 未達の場合に備える
-- すべて IF NOT EXISTS で冪等

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS notebooklm_note text,
  ADD COLUMN IF NOT EXISTS notebooklm_synced_at timestamptz;

COMMENT ON COLUMN public.wbs_tasks.notebooklm_note IS
  'NotebookLM が生成した具体的手順・留意事項 (自動更新)';
COMMENT ON COLUMN public.wbs_tasks.notebooklm_synced_at IS
  '最後に NotebookLM へソース追加した日時';
