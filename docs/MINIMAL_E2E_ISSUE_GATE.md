# Minimal E2E Issue Gate

This project uses a minimal black-box E2E gate for AI-generated feature PRs.
The goal is to review behavior instead of reading every generated line.

## Required PR Contract

Every application-behavior PR should include a `Minimal E2E Gate` section in the
PR body with these three commitments:

1. The test is implementation-detail independent.
2. The plan is limited to about three I/O cases.
3. The PR includes a Flutter `integration_test/` file or Playwright `test/e2e/`
   file, or it explains an explicit `E2E-Exception`.

Recommended cases:

- Happy path: the user-visible action succeeds.
- Error path: invalid input, missing auth, or unavailable service is handled.
- Recovery path: retry, empty state, or fallback keeps the user moving.

## Automation

`.github/workflows/minimal-e2e-gate.yml` runs on pull requests and provides two
checks:

- `PR minimal E2E declaration`: validates the PR body and detects whether app
  code changed without an E2E file or an exception reason.
- `Public E2E stability smoke`: runs the production public smoke test three
  times with Playwright to catch flaky shell, routing, or hosting regressions.

Repository branch protection should require both checks once the workflow has
landed on `main`.

## AI Author Prompt

Use this prompt for GitHub Issue implementation tasks:

```text
Before coding, define the user-visible input/output behavior. Add only a minimal
black-box E2E plan: about 3 cases covering happy path, error path, and recovery
or empty state. The E2E test must not depend on implementation details, private
state, widget class names, database row order, or mocked internals unless the
feature cannot be exercised otherwise. Prefer Flutter integration_test for app
flows and Playwright test/e2e for public web routes. If no E2E test is feasible,
write an E2E-Exception with the exact reason and the manual verification steps.
```

## Reviewer Rule

Reviewers should first inspect the E2E contract and the test's behavior focus.
Only then review code that affects auth, billing, external posting, migrations,
or other high-risk surfaces.
