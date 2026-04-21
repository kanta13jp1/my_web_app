-- WBS Codex 引き継ぎ: frontend/comparison タスクの owner_instance 再割当
-- 2026-04-21
--
-- 背景:
--   Claude quota 制限により、直近の frontend / comparison 進行タスクを
--   Codex が引き継いで開発継続する。
--   instance (レーン) は既存の VSCode / shared のまま維持しつつ、
--   担当 (= owner_instance) を Codex に付け替えて公開 WBS に反映する。

-- ============================================================
-- 1. owner_instance CHECK に codex を追加
-- ============================================================
ALTER TABLE wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'codex'
  ));

COMMENT ON COLUMN wbs_tasks.owner_instance IS
  '主担当 instance / agent。NOT NULL + ''all'' 禁止。instance=''all'' の共同責任タスクでも primary owner を必ず 1 つ指定。2026-04-21 以降は Codex も有効な担当値。';

-- ============================================================
-- 2. Codex 引き継ぎ対象タスクを再割当
-- ============================================================
UPDATE wbs_tasks
SET owner_instance = 'codex',
    progress = GREATEST(progress, 65),
    status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END
WHERE status != 'completed'
  AND title = 'DESIGN.md全ページ準拠 60%達成';

UPDATE wbs_tasks
SET owner_instance = 'codex',
    progress = GREATEST(progress, 70),
    status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END
WHERE status != 'completed'
  AND title = 'モバイルレスポンシブ完全対応';

UPDATE wbs_tasks
SET owner_instance = 'codex',
    progress = GREATEST(progress, 85),
    status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END
WHERE status != 'completed'
  AND title = '競合比較ページ最新化';

-- ============================================================
-- 3. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS Codex takeover: frontend/comparison owner reassignment',
  $md$Claude quota 制限対応として、frontend/comparison の直近進行タスク 3 件
  (DESIGN.md 全ページ準拠 60%達成 / モバイルレスポンシブ完全対応 /
  競合比較ページ最新化) の owner_instance を Codex に再割当。
  instance レーンは既存構成を維持しつつ、公開 WBS では「担当 Codex」を表示できる状態に更新。$md$,
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
