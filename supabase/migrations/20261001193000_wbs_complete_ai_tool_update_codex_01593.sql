-- Antigravity / 2026-10-01.
-- Issue #5648: [ai-tool-update] 0.159.3 (rust-v0.159.3, 2026-09-30)
-- OpenAI Codex CLI 0.159.3 adoption: Windows background console flash suppression, GPT-6.1 Sol catalog integration, and multi-AI 3-lane coordination.
-- nocheck: time-relative

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Verified OpenAI Codex CLI 0.159.3 release: adopted Windows background console window suppression (#49385), GPT-6.1 Sol catalog integration, and updated 3-lane coordination guidelines in Antigravity session.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-09-30'),
  end_date          = DATE '2026-10-01',
  remaining_work    = 'Completed: Adopted Codex CLI 0.159.3 and Claude Code 2.1.286 updates into fleet coordination.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-10-01: ai-tool-update 0.159.3%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-10-01: ai-tool-update 0.159.3 (Antigravity). Verified Codex CLI 0.159.3 changelog, confirmed console suppression on Windows background processes, adopted into fleet operating guidelines.'
  END,
  updated_at        = now()
WHERE github_issue_number = 5648;

-- In case task was tracked by title or needs insert fallback:
INSERT INTO public.wbs_tasks (
  title, category, status, progress, priority, github_issue_number, owner_instance, phase, created_at, updated_at
)
SELECT
  '[ai-tool-update] 0.159.3 (rust-v0.159.3, 2026-09-30)',
  'AI Tooling / Automation',
  'completed',
  100,
  'high',
  5648,
  'codex',
  'impl',
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks WHERE github_issue_number = 5648
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'OpenAI Codex CLI 0.159.3 更新検証とフリート採用 (#5648)',
  'OpenAI Codex CLI 0.159.3 のリリース検証を実施。Windowsでのバックグラウンドタスク実行時コンソール点滅抑制(#49385)およびGPT-6.1 Sol連携を確認し、3レーン体制(Antigravity+Codex+Claude Code)の運用ガイドラインに反映。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'OpenAI Codex CLI 0.159.3 更新検証とフリート採用 (#5648)'
);
