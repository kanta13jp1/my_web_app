# Cloud-first development runbook

## Purpose

Keep the Windows workstation responsive and avoid consuming local disk with
Flutter, Dart, Deno, browser, and build artifacts. Source editing stays local;
expensive deterministic validation runs on GitHub-hosted ephemeral runners
whenever possible.

This policy does not authorize production deployments, paid AI calls, secret
access, publishing, or other external writes. Those actions retain their
normal approval requirements.

## Routing gate

Start every implementation session with:

```powershell
python scripts/codex_session_check.py
```

Use the report's `Parallel/heavy-work gate` as the decision point. The current
repository thresholds are:

- hold when RAM usage is at least 85%
- hold when free RAM is at most 2 GB
- warn when free system-drive space is below 26 GB
- review worktree hygiene when at least 50 worktrees are registered

The gate is a routing signal, not permission to kill processes or delete
worktrees. Preserve user applications, active Git operations, dirty worktrees,
and unrelated task state.

| Gate / condition | Local work | Cloud work |
| --- | --- | --- |
| `hold` | `git status`, `git diff`, `rg`, editing, JSON/YAML parse, narrow Python policy tests | Flutter analyze/test/build, Dart format over the repository, Deno lint/test, browser tests, dependency downloads |
| `allow` | Narrow checks needed for fast feedback | Full suites and production-like builds remain preferred in CI |
| Cloud cannot reproduce | Record the reason and re-check resources before the smallest local command | Keep all reproducible checks in CI |

Do not start persistent local dev servers, emulators, media encoders, or broad
browser automation while the gate is `hold`.

## Standard branch workflow

1. Use a scoped branch/worktree and make source changes locally.
2. Run only lightweight checks proportional to the edited surface.
3. Push the branch. If it has a PR, the normal CI runs automatically.
4. Read check status and logs without downloading artifacts:

```powershell
gh pr checks <PR番号> --watch
gh run view <run-id> --log-failed
```

5. Let generated output expire with the ephemeral runner. Download an
   artifact only when a concrete failure cannot be diagnosed from logs.

## Manual cloud validation

After the cloud-first CI trigger is present on the default branch, a pushed
branch can run the full gate without opening a PR:

```powershell
git push -u origin HEAD
gh workflow run ci.yml --ref <branch>
$runId = gh run list --workflow ci.yml --branch <branch> --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Manual dispatch intentionally treats the change scope as full. Pull-request
CI remains path-scoped and is preferred for routine work.

## Failure and fallback

- If a hosted runner fails because of the change, fix the source and push
  again; do not reproduce the entire suite locally by default.
- If GitHub Actions is unavailable, run only the smallest relevant local check
  after the resource gate returns `allow`, or leave validation pending with the
  exact cloud blocker recorded.
- Do not enable the paused OpenAI/Claude review workflows as a validation
  fallback. Deterministic CI is independent of paid AI review.
- Do not auto-download build output, caches, coverage directories, or package
  archives to the workstation.

## Wrap-up evidence

Record:

- the branch and PR
- the cloud run URL and conclusion
- lightweight local checks that actually ran
- any validation omitted because it was not reproducible in the cloud
- whether the local resource gate remained `hold` or returned to `allow`
