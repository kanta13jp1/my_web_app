-- PS#4 S52: WBS タスク重複クリーンアップ (2026-04-26)
-- 原因: 20260425203000 の all→per-instance 分配が supabase db push 再実行のたびに
--       NOT EXISTS ガードが機能せず重複 INSERT を繰り返した。
-- 影響: 89 title+instance 重複コンボ / 余剰行 582 件
-- 修正: DISTINCT ON (title, instance) ORDER BY created_at ASC で最古行のみ残して DELETE
--       + 再発防止 UNIQUE INDEX を追加

-- ============================================================
-- Step 1: 重複行の削除 (最古 created_at の行を keep)
-- ============================================================
DELETE FROM public.wbs_tasks
WHERE id NOT IN (
  SELECT DISTINCT ON (title, instance) id
  FROM public.wbs_tasks
  ORDER BY title, instance, created_at ASC
);

-- ============================================================
-- Step 2: 再発防止 — title + instance の UNIQUE INDEX
-- (同じタイトル+インスタンスが重複できないようにする)
-- ON CONFLICT は code カラムベースだったが code=NULL 時に無効なため
-- title + instance の組み合わせに UNIQUE 制約を追加
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS wbs_tasks_title_instance_unique
  ON public.wbs_tasks (title, instance);

-- ============================================================
-- 実績記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS タスク重複クリーンアップ (PS#4 S52)',
  '89 title+instance 重複コンボ / 余剰行 582 件を削除。' ||
  '原因: 20260425203000 all→per-instance 分配 migration の再実行。' ||
  'UNIQUE INDEX wbs_tasks_title_instance_unique で再発防止。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
