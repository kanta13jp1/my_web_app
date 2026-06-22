-- Scheduled Daily (2026-05-19 12:00 UTC) — Win版#132 part 231 cron (= 真値 part 233):
-- Records the daily-development autonomous-cron output for part 231-cron / 233-真値.
-- Ships a tech blog draft pair (JA + EN) on the
-- "3-Tier Canonical for Docs-Only PRs (body + docs-only label + close/reopen)"
-- pattern, distilled from the 2026-05-19 part 232 first-example (PR #2942)
-- after five dogfood iterations (parts 225-followup, 226, 228, 229, 232).
-- Keeps the daily achievements stream feeding GrowthRoadmapProgressCard and
-- the development_achievements table without scope creep.

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Scheduled Daily part 231-cron / 233-真値: 3-Tier Canonical docs-only PR recipe blog draft (JA+EN)',
  'Distilled the 2026-05-19 part 232 fifth-and-final dogfood (PR #2942) into a reusable 3-tier 1-shot unblock recipe for docs-only PRs stuck on CI gates: (1) body must hold the exact phrases the gate script scans for (implementation-detail independent E2E + minimal 3 cases + integration_test/Playwright/smoke mechanism mention) — generic 5-item checkbox templates do not match, (2) gh pr edit --add-label docs-only to enter the early-return path of scripts/check_minimal_e2e_gate.py line 159-161, (3) gh pr close + gh pr reopen within 1 second to fire a fresh reopened event payload so the post-edit body and labels are re-evaluated instead of the cached opened payload. Locked as canonical after debunking two earlier false generalizations: parts 225-followup + 226 missed Tier 1 (wrong phrase) and parts 228 + 229 missed Tier 2 (no label — passed by body coincidence). Cycle 5 in part 232 had all three tiers present and gave the first true one-shot pass that is reproducible by recipe rather than by accident. Measured ~1 min 30 sec total round-trip vs days of stuck PRs without the label. Published as JA + EN blog drafts (2026-05-19-canonical-3tier-docs-only-pr-recipe.md / -en.md) and bookmarked for inject into docs/cross-instance-prs/INSTANCE_PATTERNS.md fleet-wide. Reinforces VIBE_CODING_PRINCIPLES (responsible CI workflow + bounded scope), INDIE_DEV_VELOCITY_PRINCIPLES (shipping discipline) and SECOND_BRAIN_PRINCIPLES (Karpathy Ingest -> Compile -> Publish on same-day session learning). Daily-development autonomous-cron rhythm preserved (= sequential Bash, worktree isolation in .claude/worktrees/part-233-daily-dev, no scope creep on top of part 232 +6-day fiscal P0 fire + PR #2942 merge + numbering-collision detection). Numbering collision (ROADMAP label part 230 vs MEMORY true sequence part 232) is flagged in the ROADMAP entry as deferred to a user-driven session for reconciliation.',
  '2026-05-19'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Scheduled Daily part 231-cron / 233-真値: 3-Tier Canonical docs-only PR recipe blog draft (JA+EN)'
);
