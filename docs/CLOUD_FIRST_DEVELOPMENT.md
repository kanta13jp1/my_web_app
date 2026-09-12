# Cloud-first Development Workflow

This repository treats the Windows checkout as a lightweight control plane.
GitHub and Supabase own dependency hydration, analysis, tests, builds, browser
checks, migration staging, and durable evidence.

## Route Before Work

Run the standard-library-only resource check before hydrating any toolchain:

```powershell
python scripts/cloud_first_route.py
```

Cloud execution is mandatory when any of these limits is reached:

- free disk below 30 GiB;
- free physical memory below 4 GiB;
- memory use at or above 85%.

`CLOUD_PREFERRED` means that GitHub Actions is the default validation authority.
`CLOUD_REQUIRED` additionally prohibits local dependency installs, full
Flutter/Dart/Deno checks, builds, Docker, dev servers, browsers, media work, and
local data conversion.

When memory use reaches 90% or free memory falls below 2 GiB, do not begin a
local Git operation, analyzer, test, build, browser, server, or import. Preserve
open edits and let any already-running Git operation finish. Resume resource
intensive local work only after two samples, at least eight seconds apart, both
show memory use below 85%, free memory above 2 GiB, and no Dart/Flutter process.
A user request to continue does not override this safety gate.

## Three Cloud Lanes

### 1. Remote source lane

Use a scoped `codex/` branch and a draft pull request as the durable source of
truth. When the Codex GitHub connection is available, bounded documentation,
policy, and workflow edits can be committed through GitHub without hydrating a
local checkout. Never write directly to a protected branch.

Do not mix a remote-only infrastructure change into a dirty local feature
branch. Create a separate branch from a known base commit, review the diff in a
draft PR, and merge or cherry-pick it only after CI succeeds.

If a local checkout is necessary, keep it sparse and select only the task's
write set:

```powershell
git fetch origin main
git worktree add --no-checkout -b codex/<task> C:\tmp\mwa-<task> origin/main
Set-Location C:\tmp\mwa-<task>
git sparse-checkout init --no-cone
git sparse-checkout set '/lib/target/' '/test/target/' '/AGENTS.md'
git checkout
```

Local checks must remain cheap: text inspection, `git diff --check`, and
standard-library policy tests. Do not install packages merely to make a local
check available.

### 2. Cloud validation lane

Push an immutable branch head and let GitHub Actions install dependencies, use
runner-side caches, format, analyze, test, run headless-browser smoke checks,
and build release artifacts. Pull-request CI validates the merge ref.

For a branch-only proof, dispatch the full cloud gate after pushing:

```powershell
git push -u origin HEAD
python scripts/cloud_ci_handoff.py --execute --watch
```

The helper refuses a dirty checkout, protected branch, missing remote branch,
head mismatch, or missing GitHub CLI. It passes the exact expected SHA so CI
cannot silently validate a newer moving branch.

Evernote-scoped work may also use
`.github/workflows/evernote-migration-cloud-check.yml`. That workflow formats
and validates on the runner, emits a one-day patch when the branch is not
formatted or the lockfile changes, runs focused tests, and can optionally run
the web smoke test or release build. Apply the patch only after reviewing it.

### 3. Private migration data lane

Personal exports must never be committed to Git, uploaded to GitHub Actions, or
included in logs and artifacts. Evernote ENEX files and attachments travel
directly from the selected local file stream to a private Supabase Storage
bucket using resumable, bounded chunks. The client must not create a full
in-memory copy or a second local archive.

Supabase-side workers then process the staged object sequentially:

1. record archive size, SHA-256, expected note count, and a migration batch ID;
2. parse one note at a time and copy attachments server-side;
3. commit and verify each note before advancing the ledger;
4. compare counts, hashes, attachments, searchable content, and recovery export;
5. mark the batch eligible for source deletion only after all checks succeed.

Storage remains private with user-scoped RLS. Operational logs contain IDs,
counts, hashes, timings, and error codes only. They must not contain note bodies,
attachment bytes, account credentials, or signed URLs.

Deleting the corresponding Evernote batch always requires a fresh, explicit
approval after verification. Subscription cancellation remains locked until all
batches, feature parity, recovery, and billing audits are complete.

## Artifact and Cache Policy

- Dependency caches live on GitHub runners, never in the project checkout.
- Upload only review evidence, logs, and source patches; default retention is one
  day for migration-specific artifacts.
- Never upload ENEX, Obsidian vault contents, attachment bytes, secrets, browser
  profiles, or production database exports.
- Do not download cloud build outputs unless the user needs to inspect one.
- Supabase staging objects use a documented lifecycle and are deleted only after
  the committed copy and recovery evidence are verified.

## Cleanup Boundary

- Close only servers and browser tabs opened for the current task.
- Remove only ignored caches or outputs created by the current task.
- Keep clean unmerged worktrees until the PR has review evidence.
- Never delete dirty, locked, rescued, or unrelated worktrees to gain space.
- If cloud execution is unavailable, report the infrastructure blocker. Do not
  fall back to a heavy local run while `CLOUD_REQUIRED` is active.
