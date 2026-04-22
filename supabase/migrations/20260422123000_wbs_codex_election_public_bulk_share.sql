-- WBS Codex takeover: local election public URL and bulk KPI sharing.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: make the local election
-- dashboard directly shareable without login, and replace per-prefecture X
-- sharing with one public note containing all prefecture KPIs.

INSERT INTO wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'AI統合',
  '🤖',
  5,
  '統一地方選 公開URL/一括共有ノート',
  '統一地方選700必達管理室を未ログインでも直接URLで参照できる公開ビューにし、X共有は全県連KPIを1つの共有ノートにまとめたリンク共有へ変更する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex made /local-election-700 resolve to a public view for anonymous visitors and changed X sharing to publish one all-prefecture KPI public note link.',
  'Completed in this slice. Next risk: if fully automated X posting is needed, route it through a separate daily-report permission and rate-limit task.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 公開URL/一括共有ノート'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 71),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex added direct public URL access and all-prefecture KPI public-note sharing to the local election dashboard.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ)'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 76),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex simplified mobile sharing actions by removing per-card share buttons and centralizing the bulk KPI share flow.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応 (Codex引継ぎ)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 公開URL/一括共有ノート',
  'Codex が統一地方選700必達管理室を改善。未ログインでも /local-election-700 と /public/local-election-700 から直接参照できる公開ビューにし、X共有は県連別ボタンを廃止して全県連KPIを1つの共有ノートにまとめ、その公開リンクを共有する導線へ変更した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
