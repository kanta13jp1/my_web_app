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

## Ready-to-paste snippet

AI authors create PR bodies with `gh pr create --body`, which bypasses
`.github/PULL_REQUEST_TEMPLATE.md`, so the three commitment phrases are easy to
forget. A forgotten phrase fails the gate, and because editing a PR body does
not re-run the check, the usual recovery is a wasteful close/reopen. To avoid
that, emit the canonical block straight from the checker and paste it verbatim:

```bash
# Docs/tooling change, or any PR that ships an integration_test/ or test/e2e/ file:
python scripts/check_minimal_e2e_gate.py --emit-snippet

# App-code change with no E2E file (>= 8 chars of reason after the label):
python scripts/check_minimal_e2e_gate.py --emit-snippet \
  --exception "manual verification: <what you checked and how>"
```

The emitted wording lives in `passing_snippet()` next to the pattern tables it
must satisfy, and a round-trip test in `check_minimal_e2e_gate_test.py` pins it
so it can never drift out of sync with the validator. When a local pre-flight
check (`--body-file`) FAILs, the same block is printed under a
`snippet start/end` banner so the fix is one copy away.

Always pre-flight the body locally before opening the PR:

```bash
python scripts/check_minimal_e2e_gate.py \
  --body-file pr-body.md \
  --changed-files <(git diff --name-only origin/main...HEAD)
```

## Automation

`.github/workflows/minimal-e2e-gate.yml` runs on pull requests and provides two
checks:

- `PR minimal E2E declaration`: validates the PR body and detects whether app
  code changed without an E2E file or an exception reason.
- `Public E2E stability smoke`: runs the production public smoke test three
  times with Playwright to catch flaky shell, routing, or hosting regressions.
- `Visual E2E evidence`: captures desktop and mobile screenshots for the
  landing, home, auth, Notion/WBS, and agent-org equivalents, records console
  errors, request failures, HTTP 5xx responses, `getAnimations()` settle state,
  and a low-FPS screenshot sequence for dynamic UI review.

Repository branch protection should require both checks once the workflow has
landed on `main`.

## Visual Evidence Contract

For UI-facing PRs, include the `Visual E2E Evidence` checklist in the PR body.
The default route coverage is:

- landing: `/`
- home: `/home`
- auth: `/two-factor-auth`
- Notion/WBS equivalent: `/project-gantt`
- agent-org equivalent: `/agents`

When a route is renamed, use the closest public equivalent and name it in the PR
body. The Playwright report uploads `playwright-report/` and `test-results/`,
including stable screenshots, low-FPS frames, and JSON evidence snapshots. CI
also writes `playwright-report/issue-summary.md` so failures can be copied into
a GitHub Issue without rereading the full report.

`getAnimations()` is used when the browser supports it. If a page has no active
CSS/Web Animations, the evidence snapshot records `total: 0`; this is the
documented fallback for static SEO shell pages.

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
