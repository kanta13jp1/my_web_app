# Feature consolidation loop contract

Use this reference to make each iteration comparable, recoverable, and
production-auditable.

## 1. Inventory contract

Build one row per user-visible feature or retained legacy route. Capture at
least:

| Field | Meaning |
| --- | --- |
| `display_title` | Title shown in the home catalog or another primary entry point |
| `route` | Current route or legacy URL |
| `implementation` | Page/widget or shared implementation reached by the route |
| `user_job` | The outcome the user is trying to achieve |
| `primary_output` | Saved plan, timer session, map, report, referral link, and so on |
| `persisted_entity` | Local key, database table/entity, or `none` |
| `tracking_identity` | Route label or usage key used by recent/popular/pinned views |
| `entry_points` | Home, deep link, hub, search, recommendation, notification |
| `compatibility` | Required legacy route and data behavior |
| `cluster_status` | `canonical`, `confirmed_overlap`, `candidate`, or `distinct` |
| `evidence` | Code, test, runtime, or product evidence for the classification |

Inventory from source rather than screenshots alone. Begin with
`lib/data/home_tool_catalog.dart`, route registration in `lib/main.dart`,
`lib/utils/feature_route_labels.dart`, affected page implementations, the
tools-hub usage aggregation, and route/catalog tests. Extend the search when a
feature has other entry points or persisted data.

## 2. Similarity and canonical selection

Treat two features as a confirmed overlap when at least two of these three
dimensions match and there is no material product distinction:

1. **User job** — the user hires both features for the same outcome.
2. **Primary output** — both produce or manage the same artifact or state.
3. **Persisted entity** — both read or write the same logical record, even if
   storage keys or source labels differ.

Also confirm overlap when separate routes already delegate to equivalent UI or
one implementation is a strict subset of another. Do not merge merely because
titles share a noun. Permission level, lifecycle stage, audience, safety
boundary, or meaningfully different output can justify `distinct`; record the
specific distinction.

Choose the canonical feature in this order:

1. broader complete user journey;
2. safest data compatibility and most stable public route;
3. strongest existing deep-link, SEO, and usage footprint;
4. clearer maintained architecture and test coverage;
5. least surprise for current users.

Do not choose solely by shorter code or newer filename.

## 3. Iteration ledger

Keep this table in the task handoff, Issue, or PR body. Do not create a new
tracking system when an existing task or PR is sufficient.

| Iteration | Baseline SHA | Cluster | Canonical route | Legacy routes | Data compatibility | Local proof | PR / merge SHA | Deploy / readiness | Production SHA | Remaining |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `<sha>` | `<job>` | `<route>` | `<routes>` | `<read/migrate>` | `<checks>` | `<links>` | `<runs>` | `<sha>` | `<count>` |

For each `distinct` candidate, append a one-line reason tied to the rubric. For
each unresolved candidate, state the next discriminating check rather than
leaving it as an unbounded question.

## 4. Batch compatibility contract

Before implementation, state:

- canonical title, route, implementation, and tracking identity;
- every catalog entry to remove or rename;
- every legacy URL to retain and where it delegates;
- old and new persistence sources plus read/write behavior;
- how recent/popular/pinned usage is canonicalized;
- tests proving catalog uniqueness, route compatibility, data preservation, and
  the core user journey;
- rollback path that restores routing without discarding user data.

Prefer alias routing and compatibility reads. Use a migration only when a read
bridge cannot preserve correctness or performance. Never delete legacy data in
the same batch unless that deletion is explicitly approved and independently
recoverable.

## 5. Local validation matrix

Run checks proportional to the touched layers. Use the repository-pinned Flutter
and Deno versions whenever local and CI behavior differ.

```powershell
dart format --output=none --set-exit-if-changed <changed-dart-paths>
flutter analyze
flutter test test/data/home_tool_catalog_consolidation_test.dart
flutter test test/routes/route_url_sync_test.dart
flutter test test/utils/feature_route_labels_test.dart
flutter build web --release --pwa-strategy=none
```

Add focused page, model, service, and persistence tests for the selected
cluster. When an Edge Function changes, run:

```powershell
deno fmt --check <changed-typescript-paths>
deno lint --config supabase/functions/deno.json <changed-typescript-paths>
deno check --config supabase/functions/deno.json <changed-entrypoints>
```

If a nonrequired local browser-backed test hangs, capture the command and
process state, terminate only that test, and run an equivalent focused test,
release build, and direct browser flow. Record the exception; required CI must
still pass.

Browser QA must cover:

- the canonical happy path;
- every retained legacy route in the batch;
- reload and back/forward URL behavior;
- existing legacy history when persistence changed;
- desktop and 390 px widths;
- console errors, Flutter exceptions, failed requests, and horizontal overflow.

## 6. PR and release evidence

The PR body should report the catalog count before and after, cluster mapping,
compatibility contract, deterministic checks, browser QA, minimal-E2E coverage
or honest exception, and high-risk review evidence or honest exception.

Wait for required checks and capture the actual merge SHA. Do not infer it from
the branch head. After merge, identify runs by SHA:

```powershell
gh pr checks <pr-number> --watch
gh pr view <pr-number> --json mergeCommit,url
gh run list --workflow "Deploy to Production" --commit <merge-sha> --json databaseId,headSha,status,conclusion,url
gh run watch <deploy-run-id> --exit-status
```

`Release Readiness Gate` is triggered by the deployment workflow. Match it by
its triggering deployment run and timestamps/metadata; do not accept an
unrelated scheduled or newer run as evidence.

Inspect the deployment's jobs and failed steps, not only its outer conclusion.
Production proof for this repository includes:

```powershell
Invoke-RestMethod 'https://my-web-app-b67f4.web.app/version.json'
```

The returned `commit` must equal the expected deployed merge SHA. Then smoke the
canonical and legacy URLs and repeat the essential browser QA against
`https://my-web-app-b67f4.web.app`.

Check release traceability:

```powershell
gh release view <tag> --json tagName,targetCommitish,url
git fetch --tags origin
git rev-list -n 1 <tag>
```

The resolved tag commit must equal the deployed commit. A release body that
mentions the new SHA does not compensate for a tag that still points to an old
commit. Do not move an existing tag without explicit operator authorization.

The release-broadcast notification is operational evidence. A `401` or other
notification failure is nonblocking for the live product only when the deploy,
revision, readiness, and route gates pass; record the failure and recovery owner
instead of hiding it.

## 7. Completion calculation

At the deployed SHA, recompute:

```text
unresolved = confirmed_overlap + undecided_candidates
catalog_ok = duplicate_titles == 0
             and duplicate_routes == 0
             and unregistered_catalog_routes == 0
compatibility_ok = legacy_route_failures == 0
                   and legacy_data_failures == 0
release_ok = required_checks_green
             and deploy_green
             and readiness_green
             and production_sha_matches
             and release_tag_matches
qa_ok = canonical_flows_pass
        and legacy_flows_pass
        and desktop_mobile_regressions == 0

done = unresolved == 0
       and catalog_ok
       and compatibility_ok
       and release_ok
       and qa_ok
```

If `done` is false, select the next safe cluster or repair the false gate. If
only an operational notification is false, keep product completion separate
from the documented notification recovery item. If the same unchanged blocker
survives three repair attempts, stop retrying and hand off the evidence.

## 8. Known release pitfalls

- A merge is not proof that Firebase serves that commit. Use `version.json`.
- A green deployment run can contain `continue-on-error` warnings. Inspect the
  Firebase verification, release tag, and broadcast steps.
- A pre-existing version tag can cause the release page and tag target to
  diverge. Treat the tag target as the rollback truth.
- Main may advance while a queued deployment runs. Match all evidence by SHA,
  not by "latest".
- Do not repeatedly rerun a deterministic CI failure. Reproduce the exact
  failing command and SDK locally, repair it, and push a new commit.
- Never present a skipped Claude/high-risk review as completed review.
