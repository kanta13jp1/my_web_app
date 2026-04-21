-- WBS Codex takeover scope correction.
--
-- The temporary Claude quota fallback must only move tasks that Codex
-- actually starts. 20260421053000 was intentionally broad as a fallback;
-- this migration narrows the public owner back to each lane owner except
-- for Codex-started tasks.

UPDATE wbs_tasks
SET
  owner_instance = CASE
    WHEN instance = 'all' THEN 'vscode'
    WHEN instance = 'schedule' AND title LIKE 'daily-report%' THEN 'ps1'
    WHEN instance = 'schedule' AND title LIKE 'cs-check%' THEN 'ps5'
    WHEN instance = 'schedule' AND title LIKE 'github-issue-fix%' THEN 'ps5'
    WHEN instance = 'schedule' AND title LIKE 'weekly-sns-draft%' THEN 'ps2'
    WHEN instance = 'schedule' AND title LIKE 'pr-auto-review%' THEN 'ps1'
    WHEN instance = 'schedule' AND title LIKE 'competitor-monitoring%' THEN 'ps4'
    WHEN instance = 'schedule' AND title LIKE 'infra-health-check%' THEN 'ps1'
    WHEN instance = 'schedule' AND title LIKE 'dependency-audit%' THEN 'ps1'
    WHEN instance = 'schedule' AND title LIKE 'blog-draft%' THEN 'ps2'
    WHEN instance = 'schedule' AND title LIKE 'ai-university-update%' THEN 'ps3'
    WHEN instance = 'gha' AND title LIKE 'cron-batch%' THEN 'ps6'
    WHEN instance = 'gha' THEN 'ps1'
    WHEN instance = 'windows' THEN 'win'
    WHEN instance = 'ps' THEN 'ps1'
    ELSE instance
  END,
  updated_at = now()
WHERE status <> 'completed'
  AND owner_instance = 'codex'
  AND title NOT IN (
    'DESIGN.md全ページ準拠 60%達成',
    'モバイルレスポンシブ完全対応',
    '競合比較ページ最新化',
    'Webパフォーマンス最適化 (LCP < 2.5s)',
    'BYPASS_RULES secret設定',
    'オンボーディング最適化',
    '紹介プログラム実装',
    'E2Eテスト整備 (Playwright)',
    'エラー監視強化 (Sentry連携)',
    '画像生成統合',
    'マルチモーダルAI',
    'AI大学 100社達成'
  );

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 65),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 70),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 85),
  updated_at = now()
WHERE title = '競合比較ページ最新化'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 40),
  updated_at = now()
WHERE title = 'Webパフォーマンス最適化 (LCP < 2.5s)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS Codex takeover scope corrected',
  'Claude quota 制限中の一時引き継ぎを、Codex が実際に着手したタスクに限定。過剰だった未完了全件 Codex owner 化を各 lane owner に戻した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
