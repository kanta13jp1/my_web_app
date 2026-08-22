# Site trust improvement loop design

Use this contract to make repeated review, repair, release, and production
verification requests one recoverable loop instead of a series of disconnected
audits.

## 1. Control flow

```mermaid
flowchart LR
    O[Observe production] --> R[Rank trust risks]
    R --> C[Select one defect and define contract]
    C --> F[Fix minimally and honestly]
    F --> L[Prove locally]
    L -->|pass| P[PR and required CI]
    L -. local failure .-> C
    P -->|pass| D[Merge and deploy]
    P -. CI failure .-> F
    D -->|pass| V[Verify production SHA and UX]
    D -. deploy failure .-> P
    V -->|pass| K[Record learning and next candidate]
    V -. stale revision or UX failure .-> C
    K --> O
```

The solid path advances evidence toward the user. Every failure edge stays in
the current iteration. Only verified production evidence opens the next one.

## 2. Iteration state machine

Use these states verbatim in a task handoff, Issue, or PR:

| State | Required output | Failure or pause resumes at |
| --- | --- | --- |
| `observing` | Production revision and browser evidence | `observing` |
| `ranking` | Candidate list and selected-defect rationale | `ranking` |
| `contracted` | Expected/actual, reproduction, protected behavior, test matrix | `contracted` |
| `implementing` | Scoped diff and rollback approach | `contracted` |
| `locally_proven` | Focused tests, analysis/build, responsive browser QA | `implementing` |
| `in_review` | PR and required-check evidence | `implementing` for code/CI failure |
| `deploying` | Merge SHA and matching deployment/readiness run | `in_review` for release failure |
| `production_verified` | Served SHA, tag target, desktop/mobile UX proof | `contracted` for production failure |
| `learned` | Residual risk and next candidate | `observing` |

Do not infer state from the latest branch or workflow alone. Resume from the
first state whose required output is missing.

## 3. Trust-risk ranking

Rank only evidenced candidates. Use the following dimensions as a decision aid;
the written evidence and user consequence remain authoritative.

| Dimension | Higher priority means |
| --- | --- |
| User impact | Money, data, identity, or the advertised core outcome is wrong or lost |
| Encounter likelihood | The defect occurs on first use, the default path, or a common recovery path |
| Opacity | The UI claims success or gives no honest explanation or recovery action |
| Irreversibility | The user may act, pay, save, share, or discard data based on the false state |
| Evidence confidence | Production reproduction, logs, network state, and source trace agree |

Resolve ties in this order: false success, irreversible consequence, core
journey, first-use frequency, then the smallest safe change. Cosmetic polish
cannot outrank a reliable misleading-success or data-loss defect.

## 4. Evidence contract

Each iteration records:

| Field | Content |
| --- | --- |
| `iteration_id` | Stable task/Issue identifier plus sequence number |
| `baseline_sha` | Commit served when production was observed |
| `trust_hypothesis` | Why the behavior can make a reasonable user distrust the site |
| `production_evidence` | URL, viewport, steps, visible result, console/network/persistence evidence |
| `selected_defect` | Exactly one defect and why it outranks the other candidates |
| `expected_actual` | Expected behavior versus observed behavior |
| `protected_behaviors` | Routes, auth, billing, data, analytics, copy, and flows that must remain intact |
| `fix_scope` | Responsible layer, changed files, and rollback approach |
| `local_proof` | Focused tests, failure-state test, analysis/build, desktop/mobile QA |
| `release_proof` | PR, required checks, merge SHA, deploy/readiness run, release tag |
| `production_proof` | Served SHA plus successful repaired and recovery journeys |
| `residual_risk` | Next candidate or reason no remaining candidate crosses the threshold |
| `state` | One state from the state-machine table |

Keep this record in the existing task, Issue, or PR. Do not create a parallel
tracking system unless the repository has no durable handoff surface.

## 5. Validation contract

Choose checks proportional to the touched layers. For Flutter changes, the
baseline is:

```powershell
dart format --output=none --set-exit-if-changed <changed-dart-paths>
flutter analyze
flutter test <focused-test-paths>
flutter build web --release --pwa-strategy=none
```

Add route, service, persistence, widget, or integration tests for the protected
behavior. When an Edge Function changes, run its repository-pinned Deno format,
lint, and check commands. Browser QA covers the repaired happy path and the
failure/recovery state at desktop and 390 px, including reload, back/forward,
console errors, failed requests, and horizontal overflow.

When a provider failure cannot be forced live, inject a deterministic failure in
a focused test and run the normal provider path in the browser. Record that
limitation; never simulate the production success proof.

## 6. Release and production proof

Use the repository's protected PR workflow. Match every release artifact by the
actual merge SHA, not by `latest` or timestamp alone.

```powershell
gh pr checks <pr-number> --watch
gh pr view <pr-number> --json mergeCommit,url
gh run list --workflow "Deploy to Production" --commit <merge-sha> --json databaseId,headSha,status,conclusion,url
gh run watch <deploy-run-id> --exit-status
Invoke-RestMethod 'https://my-web-app-b67f4.web.app/version.json'
```

The returned production commit must equal the expected merge SHA. Confirm the
matching release tag resolves to the same commit, then repeat the repaired and
recovery journeys on the production URL at desktop and 390 px. A notification
failure may be tracked separately only when deployment, revision, readiness,
tag, and user-journey gates all pass.

## 7. Authority and recovery

| Boundary | Authority required |
| --- | --- |
| Inspect code, workflow state, and public production behavior | Review or diagnosis request |
| Edit and validate in a scoped worktree | Request to fix or implement |
| Push, open/update PR, merge, deploy, or notify | Explicitly included in the request; `本番デプロイまで` covers the normal protected release path |
| Direct production data write, destructive migration, force-push, protection bypass, or existing-tag rewrite | Separate exact authorization; never infer it from deployment authority |

If authority or credentials end at a gate, preserve the ledger and report the
exact next command or action. If CI or deployment fails, stay in the same
iteration. If `main` advances during release, match the target by SHA and rerun
only checks invalidated by the update.

## 8. Iteration completion

One iteration is closed only when all applicable gates are true:

```text
iteration_done = evidence_gate
                 and honesty_gate
                 and deterministic_gate
                 and regression_gate
                 and release_gate
                 and production_gate
```

When release is outside the authorized scope, report `locally_proven` rather
than weakening the predicate. A new iteration starts only after
`production_verified` and `learned`, or in a later task that explicitly accepts
the recorded local-only handoff.
