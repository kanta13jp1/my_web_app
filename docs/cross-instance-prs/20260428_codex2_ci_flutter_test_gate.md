# Codex#2 CI Flutter Test Gate

## Context

Production hotfix triage exposed a CI trust issue while rebasing Codex PRs:
the GitHub Actions CI run was green even though the `Run tests` step logged
Flutter test failures.

Root cause:

- `.github/workflows/ci.yml` ran `flutter test --coverage` on the default VM
  platform.
- Several app imports use web-only `dart:js_interop` / `package:web` APIs.
- The step had `continue-on-error: true`, so the PR check stayed green even
  when the test process failed.

## Change

- Run the VM-safe Flutter suite with `continue-on-error: false`.
- Run lightweight web-import smoke coverage (`test/web_import_smoke_test.dart`)
  on Chrome with `continue-on-error: false`.
- Only run Codecov upload when `coverage/lcov.info` exists.
- Move the shared Supabase test/client getter out of `main.dart` so service
  tests do not import the full app route catalog and web-only pages.
- Keep `test/main_test.dart` and `test/readme_features_test.dart` out of this
  quick Chrome gate for now; they are heavier integration tests and need a
  separate stabilization pass before becoming hard-fail Chrome coverage.

## Verification

- `git diff --check`
- GitHub Actions CI on PR after push

## Ownership

Codex#2 owns this as CI / sync / ops follow-up from OPS-28 trigger #4
(`main`/PR truth drift).
