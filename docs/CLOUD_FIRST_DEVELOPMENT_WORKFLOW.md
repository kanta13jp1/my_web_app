# Cloud-first development workflow

This repository treats the local Windows PC as a lightweight control plane.
GitHub owns source preservation, dependency hydration, analysis, tests, builds,
browser checks, and short-lived review artifacts. Supabase owns private
migration staging and server-side processing.

## Default execution path

Use this order for every task:

1. Inspect only the small amount of local state needed to avoid overwriting user
   work.
2. Prefer the GitHub connector, Git Data API, or GitHub web editor for bounded
   source changes. Do not create a local worktree merely to edit files that the
   remote API can update safely.
3. Commit to a scoped `codex/` branch and open a draft pull request.
4. Dispatch GitHub Actions against the exact 40-character branch HEAD.
5. Read logs and summaries remotely. Download an artifact only when a person
   must inspect it.
6. Keep production deployment in the deployment workflow, never on the local
   PC.

Use GitHub Codespaces only when interactive multi-file editing is genuinely
needed and after checking quota or billing. A codespace is never created
automatically.

## Resource boundary

Run locally only lightweight control-plane operations:

- inspect `git status`, a small diff, or a single text file;
- preserve a small scoped edit when no remote edit route exists;
- push a committed branch, update a pull request, or dispatch a workflow;
- read Actions logs or perform a short HTTP/revision check.

Run in GitHub Actions:

- `flutter pub get`;
- `flutter analyze`;
- `flutter test`;
- `flutter build web`;
- browser smoke tests;
- generated artifacts and release gates.

Run in Supabase or another private cloud worker:

- streaming ENEX parsing;
- attachment transfer, hashing, OCR, and media conversion;
- migration ledger updates and aggregate audits;
- recovery export generation and verification.

Do not start a local Flutter/Dart build, analysis, test, browser automation,
server, media pipeline, or ENEX expansion when RAM usage is at least 85%, free
physical memory is below 4 GiB, or free disk is below 30 GiB. Preserve the
current edit remotely and dispatch a cloud workflow. Resume resource-intensive
local work only after two measurements, at least eight seconds apart, both show
RAM below 85%, at least 4 GiB free memory, at least 30 GiB free disk,
and no Dart/Flutter process.

A request to continue does not bypass this resource gate.

## Exact-revision cloud validation

`.github/workflows/cloud-development.yml` supports these profiles:

| Profile | Cloud work |
| --- | --- |
| `workspace` | Validate cloud workspace descriptors without Flutter |
| `format` | Format changed Dart files and preserve a one-day patch artifact |
| `analyze` | Resolve dependencies and run static analysis |
| `test` | Resolve dependencies and run tests |
| `web-build` | Resolve dependencies and create a release web build |
| `full` | Analyze, test, and create a release web build |

Manual runs require the exact branch HEAD. This prevents a moving branch from
silently validating a different revision:

```powershell
$branch = 'codex/<task>'
$sha = gh api "repos/kanta13jp1/my_web_app/commits/$branch" --jq .sha
gh workflow run cloud-development.yml --ref $branch `
  -f profile=full `
  -f expected_head_sha=$sha
```

When the GitHub connector is available, perform the same branch lookup and
workflow dispatch through the connector so the local PC does not need GitHub
CLI or a hydrated checkout.

A pull-request event validates GitHub's immutable event revision. A reusable
workflow caller may also pass `expected_head_sha`; if supplied, the same
lowercase 40-character validation is enforced.

## Cloud editing workspace

The default `.devcontainer/devcontainer.json` is a lightweight GitHub
Codespaces control plane. It does not install Flutter, run `flutter pub get`,
open a browser, or create build output during startup.

The former rootless-Podman Flutter environment remains available at
`.devcontainer/flutter-local/devcontainer.json`. It is a resource-heavy,
explicit fallback and must never be selected automatically.

## Personal migration data

Personal ENEX files, Obsidian vault contents, attachments, credentials, browser
profiles, production exports, and signed URLs must never be committed to Git,
uploaded to Actions, printed in logs, or preserved as workflow artifacts.

The browser streams a selected export directly to an owner-private Supabase
Storage bucket in bounded resumable chunks. Server-side workers process the
staged object sequentially. Logs and summaries contain only opaque IDs, counts,
hashes, timings, and gate states.

Evernote deletion always requires a fresh explicit approval after a batch is
fully verified. Subscription cancellation remains blocked until all data,
feature parity, recovery, account, and billing checks pass.

## Artifacts, caches, and cleanup

- Hosted-runner dependency caches stay in GitHub.
- Web builds and review patches have one-day retention.
- Do not download build artifacts merely to redeploy them locally.
- Never delete unrelated local worktrees or caches to manufacture headroom.
- Close only resources opened by the current task.
- Keep unmerged work preserved in the remote branch and draft pull request.

If cloud execution is unavailable, report the infrastructure blocker. Do not
fall back to a heavy local run while the resource gate is active.

## Notion migration cloud audit

Use the read-only cloud audit to inspect the latest migration batch without opening Notion, running Flutter locally, or downloading source content:

```powershell
gh workflow run notion-migration-cloud-audit.yml --ref main
```

The job reads only aggregate progress from the owner-scoped migration control plane. Its log, job summary, and one-day artifact contain counts and gate states only; page titles, note bodies, attachments, workspace identifiers, source IDs, and credentials are excluded.

The audit never imports, deletes, or cancels a subscription. A source deletion gate opens only when at least one item has passed all seven checks and has separately recorded owner authorization. The subscription cancellation gate opens only after every item is source-deleted, every required capability is verified, and the guarded migration batch is complete.

## Notion WBS cloud import

Use the serialized manual workflow for WBS data that has already been inventoried and durably staged. It never needs a local Flutter checkout, browser session, Notion page download, or local build cache.

First run a read-only plan from trusted `main`:

```powershell
gh workflow run notion-wbs-cloud-import.yml --ref main -f mode=plan -f safe_offset=0 -f limit=100
```

Read the sanitized one-day artifact or job summary. It contains counts, the current SHA-256 plan digest, mapping-gate status, and no titles, page IDs, task IDs, paths, or credentials. Apply only that exact plan digest and at most 100 deterministic logical groups:

```powershell
gh workflow run notion-wbs-cloud-import.yml --ref main -f mode=apply -f expected_plan_sha256=<digest-from-latest-plan> -f safe_offset=0 -f limit=100
```

After every applied batch, run `plan` again because inserts and updates intentionally change the digest. Advance `safe_offset` only after the prior batch has persisted destination and migration evidence. The workflow serializes runs, bulk-upserts each phase, verifies destination content before recording import evidence, and is safe to re-run after an interrupted phase. Conflicting groups stay untouched for separate preservation review.

This workflow never deletes Notion content. Source deletion remains controlled by seven per-item verification checks plus separately recorded owner authorization; subscription cancellation remains blocked until every item and required capability passes the migration control-plane gates. 

### Repairing a staged inventory gap

When a plan reports missing source items, use `repair_inventory` only if the
same sanitized plan reports that every missing item is repairable and the
inventory-repair gate is open. The repair promotes the already durable,
owner-scoped WBS staging record into the latest migration inventory without
importing it, overwriting an existing inventory row, or deleting any Notion
content:

```powershell
gh workflow run notion-wbs-cloud-import.yml --ref main -f mode=repair_inventory -f expected_plan_sha256=<digest-from-latest-plan> -f safe_offset=<same-offset> -f limit=<same-limit>
```

After the repair, run `plan` again for the exact same range. Continue with
`apply` only when missing items and mapping conflicts are both zero and the
normal safe-apply gate is open. Artifacts and summaries remain content-free;
they expose counts and gate states, never page titles, source IDs, task IDs, or
payloads.

## Cloud formatter output

Together with `format`, the workflow now exposes six profiles; the original
five validation profiles remain unchanged.

Use the `format` profile when the repository-pinned Dart formatter differs
from the SDK available on the local machine. The runner formats only Dart
files changed between the selected branch and the default branch. It does not
push or commit changes.

```powershell
gh workflow run cloud-development.yml --ref <branch> -f profile=format -f expected_head_sha=<exact-40-character-branch-head>
```

When formatting changes are needed, the run uploads a one-day
`cloud-format-<run-id>` artifact containing a binary patch, a manifest, and
the formatted files. Review the patch before applying or committing it. This
keeps dependency resolution and formatter-version work on GitHub-hosted
runners without bypassing the repository's human-review requirement for the
separate bot-commit auto-fix workflow.
