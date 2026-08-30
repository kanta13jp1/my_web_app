---
name: site-trust-improvement-loop
description: Review the deployed my_web_app site for user-visible defects that erode trust, select and fix exactly one highest-priority defect per iteration, prove it primarily in cloud CI, release it through the authorized protected path, verify the exact production revision, and feed the evidence into the next iteration. Use for requests to review the site, fix the most trust-damaging bug, continue that work, or carry it through production; do not use for broad redesigns, generic feature work, or security audits unless those are explicitly requested.
---

# Site Trust Improvement Loop

Close one evidence-backed trust gap at a time. The loop starts from the deployed
user experience and closes only when the exact released revision is verified in
production. A repeated request such as `進めて` resumes the open iteration; it
must not restart the audit, duplicate a fix, or select a new defect prematurely.

## Establish state and authority

1. Read the repository `AGENTS.md`, inspect the working tree, and route the
   task before hydrating a toolchain:

   ```powershell
   python scripts/cloud_first_route.py
   python scripts/codex_session_check.py
   python scripts/ai_tool_watch.py --print-only
   ```

2. Treat the Windows checkout as a lightweight control plane. Prefer GitHub/API
   inspection for read-only work, GitHub web editing for tiny changes, and the
   repository's lightweight Codespaces configuration for interactive edits.
   Create a local checkout only when needed; then use a sparse task worktree
   from current `origin/main` and preserve unrelated user changes.
3. Read [references/loop-design.md](references/loop-design.md) before auditing,
   changing, or releasing the site.
4. Recover the current iteration before doing new work. Inspect the ledger,
   branch, PR, checks, deployment runs, production `version.json`, and any saved
   browser evidence. Continue from the first unproven gate.
5. Record the authorized boundary:
   - Review and diagnosis authorize read-only production inspection.
   - A request to fix authorizes scoped local changes and validation.
   - Push, PR, merge, deployment, production writes, tag changes, or external
     messages require authority from the user's request.
   - `本番デプロイまで` authorizes the normal protected PR, merge, deployment,
     and production-verification path. It does not authorize branch-protection
     bypass, force-push, destructive migration, direct ad-hoc production writes,
     or moving an existing release tag.
6. Obey the resource route for the whole iteration. `CLOUD_REQUIRED` prohibits
   local dependency installation, Flutter/Dart/Deno analysis or tests, builds,
   Docker, dev servers, browser automation, artifact downloads, and local child
   workers. `CLOUD_PREFERRED` still makes GitHub Actions the validation
   authority; it permits only targeted lightweight local checks by default.

## Preserve trust invariants

- Visible success must mean the promised operation actually succeeded.
- Demo, cached, synthetic, fallback, or partial results must identify their
  limitation and must not impersonate a live provider result.
- Do not enable save, share, purchase, or another irreversible downstream action
  when the displayed result is not durable or equivalent to the promised result.
- Keep error and recovery copy specific enough for the user to understand what
  happened and what is safe to try next.
- Preserve working routes, auth, billing, stored data, analytics, and source
  attribution unless the selected defect requires an explicitly reviewed change.
- Select exactly one trust defect per iteration. Avoid opportunistic redesign or
  unrelated cleanup.

## Run one bounded iteration

Maintain the iteration ledger from the loop design.

1. **Observe production** — Pin the served commit and inspect the primary journey
   on desktop and 390 px. Record visible state, copy, console errors, failed
   requests, persistence behavior, and recovery behavior. Prefer production
   evidence; use local inspection to explain it.
2. **Rank trust risks** — List evidenced candidates and rank them by user impact,
   encounter likelihood, opacity, irreversibility, and evidence confidence.
   Choose exactly one. False success, data loss, broken auth/payment, misleading
   fallback, or a failed advertised first-use journey outrank cosmetic defects.
3. **Reproduce and contract** — State expected versus actual behavior, the
   smallest deterministic reproduction, suspected layer, protected behaviors,
   and the validation matrix before editing. Distinguish code defects from
   configuration, provider outage, stale deployment, and test-only failures.
4. **Fix minimally and honestly** — Change the narrowest responsible layer.
   Make fallback and failure states explicit, prevent unsafe downstream actions,
   and keep provider or persistence logic out of UI widgets when practical. Keep
   edits remote or sparse; do not hydrate project dependencies just to edit.
5. **Prove in cloud** — Locally run only cheap checks such as `git diff --check`
   and dependency-free targeted policy tests. When push authority exists,
   preserve the exact commit on the scoped branch and dispatch the smallest
   `cloud-development.yml` profile that proves the iteration through
   `scripts/cloud_ci_handoff.py`; use `full` before review handoff. Rely on
   hosted PR CI and hosted E2E/browser checks for focused tests, failure-state
   tests, analysis, release build, desktop/390 px behavior, console/network,
   navigation, reload, back/forward, and overflow proof. If cloud browser proof
   is unavailable, record the gap instead of starting a local dev server while
   `CLOUD_REQUIRED` is active.
6. **Release when authorized** — Open or update a compliant PR for the pushed
   exact SHA, wait for required checks, repair failures, merge through the
   protected path, identify the actual merge SHA, and follow the matching
   deployment and readiness runs by SHA. A workflow dispatch or build artifact
   is not a deployment.
7. **Verify production when authorized** — Confirm production `version.json`,
   release tag, and deployment evidence resolve to the expected merge SHA. Run
   the repaired journey and its failure/recovery path against production on
   desktop and 390 px. A green workflow with a stale revision is a failed gate.
8. **Learn and feed forward** — Record the selected-defect rationale, evidence,
   protected behaviors, diff, checks, PR/merge/deploy identifiers, production
   proof, residual risk, and next candidate. A failed gate returns to the same
   iteration. Only a production-verified iteration may return to observation and
   select another defect.

By default, finish one highest-priority iteration. Continue another iteration
when the user asks to continue or explicitly requests an ongoing sweep. If
release authority is absent, stop at `cloud_ready` with the lightweight proof,
unpublished commit or patch, and exact resume action; never call the change
`cloud_proven` or production-complete.

## Enforce the gates

- **Evidence gate** — The selected defect is reproduced or supported by strong
  production evidence, with expected and actual behavior recorded.
- **Honesty gate** — The UI never presents fallback, demo, stale, or failed work
  as an equivalent live success.
- **Deterministic gate** — The failure and recovery states have a repeatable
  hosted test even when an external provider failure cannot be forced live.
- **Cloud regression gate** — The exact pushed SHA passes the required cloud
  profile, PR checks, protected behavior, and responsive hosted browser checks.
- **Release gate** — Required PR checks are green and the merge SHA is known.
- **Production gate** — The served revision, tag, and user journey match that SHA.

If any gate fails, repair that gate within the same iteration. Diagnose before
rerunning. After three failed repair attempts for the same unchanged root cause,
stop retrying and report the blocker, evidence, and safest resume path.

## Report the result

Report the selected defect and why it ranked first, the user-visible correction,
protected behavior, resource route, local-control-plane footprint, cloud run URL
and exact SHA, branch/PR/merge SHA, deployment and production-revision proof,
remaining trust risks, and the next loop entry point. State the first false gate
plainly when the iteration is not closed.
