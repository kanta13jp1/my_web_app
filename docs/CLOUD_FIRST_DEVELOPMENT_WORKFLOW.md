# Cloud-first development workflow  This repository defaults heavy development work to GitHub-hosted runners so a local Windows machine does not need to hold Flutter build caches or run memory-intensive analysis, tests, and web builds.  ## Execution boundary  Run locally only lightweight control-plane operations:  - inspect and edit a small scoped change; - inspect `git status` and the final diff; - push a branch or update a pull request; - dispatch a GitHub Actions workflow and read its logs; - perform a short production HTTP/revision smoke check.  Run in GitHub Actions:  - `flutter pub get`; - `flutter analyze`; - `flutter test`; - `flutter build web`; - release and deployment gates; - generated build artifact creation.  Do not start a local Flutter/Dart build, analysis, test, browser automation, or media pipeline when RAM usage is at least 85% or free physical memory is below 2 GB. Preserve edits, dispatch the cloud check, and wait for its result instead.  ## Cloud editing workspace  Use the default `.devcontainer/devcontainer.json` with GitHub Codespaces when a change needs an interactive editor. It intentionally uses the GitHub default Codespaces image as a lightweight control plane: it provides Git and GitHub CLI, but it does not install Flutter, run `flutter pub get`, or create build output. The workflow guide opens automatically.  Create a codespace only after checking the payer and available quota:  ```powershell gh codespace create -r kanta13jp1/my_web_app -b <branch> --devcontainer-path .devcontainer/devcontainer.json ```  Stop or delete the codespace when the edit is preserved in a remote branch:  ```powershell gh codespace stop -c <codespace-name> gh codespace delete -c <codespace-name> ```  For the smallest edits, prefer the GitHub web editor or Git Data API and skip provisioning a codespace. GitHub Codespaces can incur usage charges after included quota; this repository never creates one automatically.  The former rootless-Podman Flutter environment remains available at `.devcontainer/flutter-local/devcontainer.json`. It is a resource-heavy local fallback, not the default. Select it only when local RAM and disk are healthy and local execution is explicitly required. ## Manual cloud validation  The workflow supports five profiles:  | Profile | Cloud work | | --- | --- | | workspace | validate cloud/local workspace descriptors without installing Flutter | | `analyze` | dependency resolution and static analysis | | `test` | dependency resolution and tests | | `web-build` | dependency resolution and release web build | | `full` | analysis, tests, and release web build |  Dispatch against the branch that contains the change:  ```powershell gh workflow run cloud-development.yml --ref <branch> -f profile=full ```  Find and watch the run without creating local build output:  ```powershell $runId = gh run list --workflow cloud-development.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId' gh run watch $runId --exit-status ```  Use `workspace` for dev-container-only changes, a narrower Flutter profile while iterating, and `full` before merge. The workflow cancels an older run for the same ref/profile, checks out only one commit of history, reuses the hosted Flutter cache, and keeps web artifacts for one day.  ## Pull requests and deployment  A pull request that changes this policy or its workflow runs the full cloud check automatically. Product pull requests continue to use the repository CI as the merge gate. Production deployment remains owned by `.github/workflows/deploy-prod.yml`; do not download a web build and deploy it from the local PC.  Verify deployment by matching the production `version.json` commit to the merged commit and checking the target route over HTTP. Browser QA is optional when API/HTTP evidence is sufficient and should run only after local resource pressure is safe.  ## Recovery  If a cloud run fails, inspect its logs and make the smallest source change. Do not reproduce a runner-scale failure locally unless the user explicitly requests it and the resource gate is healthy. Artifacts are temporary evidence, not a long-term store.  ## Notion migration cloud audit  Use the read-only cloud audit to inspect the latest migration batch without opening Notion, running Flutter locally, or downloading source content:      gh workflow run notion-migration-cloud-audit.yml --ref main  The job reads only aggregate progress from the owner-scoped migration control plane. Its log, job summary, and one-day artifact contain counts and gate states only; page titles, note bodies, attachments, workspace identifiers, source IDs, and credentials are excluded.  The audit never imports, deletes, or cancels a subscription. A source deletion gate opens only when at least one item has passed all seven checks and has separately recorded owner authorization. The subscription cancellation gate opens only after every item is source-deleted, every required capability is verified, and the guarded migration batch is complete. 
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
gh workflow run cloud-development.yml --ref <branch> -f profile=format
```

When formatting changes are needed, the run uploads a one-day
`cloud-format-<run-id>` artifact containing a binary patch, a manifest, and
the formatted files. Review the patch before applying or committing it. This
keeps dependency resolution and formatter-version work on GitHub-hosted
runners without bypassing the repository's human-review requirement for the
separate bot-commit auto-fix workflow.
