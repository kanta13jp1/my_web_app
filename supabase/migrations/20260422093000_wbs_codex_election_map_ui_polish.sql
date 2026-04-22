-- WBS Codex takeover: local election Japan map UI polish.
-- 2026-04-22
--
-- This keeps the owner scoped to the two frontend tasks Codex actually
-- touched while recording the second-pass map UI improvement.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 67),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex polished the 統一地方選 Japanese map UI with an ocean-map surface, region labels, selected-prefecture badge, and priority meter.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 72),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex kept the Japan map responsive with bounded labels and a stacked mobile detail panel.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 日本地図UI 改善',
  'Codex が統一地方選700必達管理室の日本地図UIを追加改善。海面背景、地域ラベル、選択中県連バッジ、重点度バーを追加し、WBS進捗を DESIGN 67% / モバイル 72% に更新した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
