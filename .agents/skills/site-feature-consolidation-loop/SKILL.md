---
name: site-feature-consolidation-loop
description: Consolidate overlapping user-facing features in the my_web_app Flutter web application through bounded compatibility-preserving batches, deterministic validation, reviewed release, and production verification, then repeat until the deployed catalog has no unresolved overlap. Use for requests to list and merge similar site functions, continue feature consolidation, or finish that consolidation through production; do not use for an ordinary isolated feature change.
---

# Site Feature Consolidation Loop

Turn a crowded feature catalog into one canonical experience per user job without
breaking legacy URLs, stored data, analytics, or release traceability. The loop is
complete only when a fresh inventory of the deployed revision satisfies every
completion gate.

## Establish scope and authority

1. Read the repository `AGENTS.md`, check the working tree, and run:

   ```powershell
   python scripts/codex_session_check.py
   python scripts/ai_tool_watch.py --print-only
   ```

2. Use a fresh worktree from current `origin/main` when the root worktree is
   dirty. Preserve all unrelated user changes.
3. Read [references/loop-contract.md](references/loop-contract.md) before
   inventory, implementation, or release work.
4. Record the release boundary before making external changes:
   - Inventory, local edits, and local checks remain within an ordinary change
     request.
   - Pushing, opening or updating a PR, merging, deploying, writing production
     data, rewriting a tag, or sending notifications requires authority from the
     user's request.
   - A request such as `本番デプロイまで` authorizes the normal protected-PR and
     workflow release path. It does not authorize bypassing branch protection,
     force-pushing, rewriting an existing release tag, destructive migrations,
     or direct ad-hoc production writes.

## Preserve these invariants

- Consolidate behavior, not just labels. A single home entry that still leaves
  duplicate pages, tracking identities, or incompatible stores is unresolved.
- Keep one canonical route and implementation per confirmed overlap cluster.
  Continue accepting each legacy route unless the user explicitly approves a
  breaking removal.
- Canonicalize recent/popular/pinned usage and route labels so aliases cannot
  reappear as separate features.
- Preserve readable history. Prefer compatibility reads and explicit source
  mapping over deleting or silently abandoning legacy records.
- Bound a batch to one overlap cluster, or at most four tightly coupled legacy
  routes that all delegate to the same canonical feature.
- Never manufacture a review result or treat a skipped high-risk review as if it
  ran. Use the repository's honest exception declaration when applicable.

## Run the loop

Maintain an iteration ledger using the template in the loop contract. For each
iteration:

1. **Inventory** — Pin the baseline commit and enumerate visible catalog entries,
   registered and legacy routes, page implementations, user jobs, outputs,
   persisted entities, and tracking labels.
2. **Cluster** — Mark exact duplicates and semantic candidates. Confirm overlap
   using the user-job/output/data rubric; record evidence when similar-looking
   features are intentionally distinct.
3. **Select** — Choose the highest-value safe cluster. Prefer visible duplication
   and low migration risk; isolate auth, billing, destructive data, or major
   product decisions for separate approval.
4. **Contract** — Name the canonical feature and define route, data, analytics,
   discoverability, test, and rollback behavior before editing.
5. **Implement** — Route aliases to the canonical implementation, remove only
   obsolete implementations, add compatibility reads or migrations, and update
   catalog and tracking sources together.
6. **Prove locally** — Run changed-target analysis and tests, route/catalog
   contract tests, relevant Deno checks, a release web build, and desktop plus
   390 px browser QA. Fix failures before release.
7. **Release when authorized** — Push the scoped branch, open a compliant PR,
   wait for required checks, merge through the protected path, identify the
   exact merge SHA, and follow the matching deployment and readiness runs.
8. **Verify production when authorized** — Confirm `version.json` reports the
   expected merge SHA, legacy and canonical routes work, the release tag points
   to that SHA, and desktop/mobile QA has no new console or layout regression.
9. **Re-inventory** — Rebuild the inventory from the released SHA, not the old
   working copy. Mark the cluster resolved, count remaining confirmed clusters,
   and either select the next batch or evaluate completion.

If release authority is absent, repeat safe local batches through step 6 and
stop at a clearly reported release gate. Do not describe the work as
production-complete.

## Declare completion only with evidence

All of the following must be true for the deployed merge SHA:

- zero confirmed overlap clusters remain;
- zero duplicate visible titles or duplicate catalog routes remain;
- every catalog route is registered, and every retained legacy route reaches
  its documented canonical feature;
- canonical analytics/usage identity and legacy data compatibility are tested;
- relevant local checks, required PR checks, deployment, and release readiness
  are green;
- production `version.json` matches the merge SHA and route/browser smoke tests
  pass at desktop and 390 px;
- the release tag used by the release points to the deployed SHA;
- notification failures, review exceptions, and nonblocking operational gaps are
  recorded with a recovery owner or issue; and
- the scoped worktree has no unintended changes.

Exact-title deduplication alone is never sufficient. A candidate classified as
intentionally distinct may be excluded only with user-job, output, or data-model
evidence in the ledger.

## Bound retries and escalation

- Diagnose before rerunning. Rerun a workflow once only when logs support a
  transient cause.
- After three failed repair attempts for the same unchanged root cause, stop the
  retry loop and report the blocker, evidence, and safest recovery path.
- If the inventory expands into unrelated domains, or consolidation would alter
  auth, billing, permissions, destructive data, or public contracts, pause that
  cluster for product or authority review while continuing other safe clusters.
- A successful merge is not a deployment. A successful deployment with a stale
  production revision or mismatched tag is not a fully auditable completion.
- Do not rewrite a mismatched tag. Repair the versioning workflow or request
  explicit release-operator direction.

## Report the result

Give the user the final catalog count, resolved clusters, retained aliases,
validation summary, PR and merge SHA, matching deployment/readiness evidence,
production revision, release-tag result, remaining cluster count, and any
nonblocking recovery item. If the completion predicate is false, say which gate
remains false and continue the next safe iteration when possible.
