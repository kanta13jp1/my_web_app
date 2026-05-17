-- Scheduled Daily (2026-05-17 12:00 UTC) — Win版#132 part 225:
-- Records the daily-development autonomous-cron output for part 225.
-- Ships a tech blog draft pair (JA + EN) on the
-- "PR Gate Declaration Body Patch + Close/Reopen" pattern, distilled
-- from the 2026-05-17 part 224 first-example (PR #2543 + #2544).
-- Keeps the daily achievements stream feeding GrowthRoadmapProgressCard
-- and the development_achievements table without scope creep.

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Scheduled Daily part 225: PR Gate Declaration Body Patch + Close/Reopen pattern blog draft (JA+EN) for stuck CI gates',
  'Distilled the 2026-05-17 part 224 first-example (PR #2543 + #2544) into a reusable 2-tier unblock pattern for stuck CI gates: (1) explicit 5-item body declaration (Minimal-E2E / High-risk diff / Backward-compatibility / Rollback plan / Owner sign-off) so body-scanning gates flip into "declaration mode" and pass, (2) gh pr close + gh pr reopen within 1 second so a fresh reopened event ships the post-edit body and discards any payload cached at opened. Measured 30 sec round-trip vs 5 min wait for body-edit-only, on both PRs in the same session. Documents the failure mode (event payload pinned at opened, rerun replays stale payload, gh pr edit emits only edited event), the safe-application scope (owner-authored single-author PRs with heuristic gates), and the do-not-apply boundary (gates inspecting code substance, PRs with approval-reset branch protection). Published as JA + EN blog drafts (2026-05-17-pr-gate-body-declaration-close-reopen.md / -en.md) extending the multi-platform tech-blog horizontal-deploy routine. Reinforces VIBE_CODING_PRINCIPLES (responsible CI workflow + bounded scope) + INDIE_DEV_VELOCITY_PRINCIPLES (shipping discipline). Daily-development autonomous-cron rhythm preserved (= sequential Bash, worktree isolation in .claude/worktrees/part-225-daily-dev, no scope creep on top of part 224 6-deliverable ship).',
  '2026-05-17'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Scheduled Daily part 225: PR Gate Declaration Body Patch + Close/Reopen pattern blog draft (JA+EN) for stuck CI gates'
);
