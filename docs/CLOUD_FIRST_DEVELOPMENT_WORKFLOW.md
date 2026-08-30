# Cloud-first development workflow

This repository defaults heavy development work to GitHub-hosted runners so a local Windows machine does not need to hold Flutter build caches or run memory-intensive analysis, tests, and web builds.

## Execution boundary

Run locally only lightweight control-plane operations:

- inspect and edit a small scoped change;
- inspect `git status` and the final diff;
- push a branch or update a pull request;
- dispatch a GitHub Actions workflow and read its logs;
- perform a short production HTTP/revision smoke check.

Run in GitHub Actions:

- `flutter pub get`;
- `flutter analyze`;
- `flutter test`;
- `flutter build web`;
- release and deployment gates;
- generated build artifact creation.

Do not start a local Flutter/Dart build, analysis, test, browser automation, or media pipeline when RAM usage is at least 85% or free physical memory is below 2 GB. Preserve edits, dispatch the cloud check, and wait for its result instead.

## Manual cloud validation

The workflow supports four profiles:

| Profile | Cloud work |
| --- | --- |
| `analyze` | dependency resolution and static analysis |
| `test` | dependency resolution and tests |
| `web-build` | dependency resolution and release web build |
| `full` | analysis, tests, and release web build |

Dispatch against the branch that contains the change:

```powershell
gh workflow run cloud-development.yml --ref <branch> -f profile=full
```

Find and watch the run without creating local build output:

```powershell
$runId = gh run list --workflow cloud-development.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Use a narrower profile while iterating and `full` before merge. The workflow cancels an older run for the same ref/profile, checks out only one commit of history, reuses the hosted Flutter cache, and keeps web artifacts for one day.

## Pull requests and deployment

A pull request that changes this policy or its workflow runs the full cloud check automatically. Product pull requests continue to use the repository CI as the merge gate. Production deployment remains owned by `.github/workflows/deploy-prod.yml`; do not download a web build and deploy it from the local PC.

Verify deployment by matching the production `version.json` commit to the merged commit and checking the target route over HTTP. Browser QA is optional when API/HTTP evidence is sufficient and should run only after local resource pressure is safe.

## Recovery

If a cloud run fails, inspect its logs and make the smallest source change. Do not reproduce a runner-scale failure locally unless the user explicitly requests it and the resource gate is healthy. Artifacts are temporary evidence, not a long-term store.