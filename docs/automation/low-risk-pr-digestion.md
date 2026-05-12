# Low-Risk PR Digestion

Issue: #1565

This workflow turns "small enough to automate" work into a visible queue, not an
auto-merge path. It supports the current two-instance flow:

- Claude Code #1 owns boundaries, exception policy, and high-risk judgment.
- Codex #1 owns the classifier implementation, workflow wiring, and scoped PRs.
- GitHub Actions owns evidence artifacts and required checks.

## Candidate Conditions

A PR can be marked as a low-risk digestion candidate only when all of these are
true:

- changed files are limited to docs, deterministic check scripts, tests,
  selected WBS/Issue workflows, dependency metadata, or Dependabot config;
- file count is 12 or less and total churn is 600 lines or less;
- labels and title/body do not mention high-risk areas;
- the PR is not a draft;
- required checks still run before review.

Issues can be listed as candidates only when they carry a low-risk label such as
`documentation`, `docs`, `dependencies`, `dependabot`, `automation`, or `wbs`
and do not contain high-risk keywords.

## Stop Conditions

Autonomous digestion stops immediately for:

- secrets, credentials, tokens, auth, payment, billing, Stripe, subscriptions;
- database migrations, RLS, `service_role`, Supabase Edge Functions;
- production deploy, Firebase deploy, release tags, Slack/notification delivery;
- mobile release, legal, tax, or business-owner decisions;
- unclassified file paths, more than 12 files, large churn, or draft PRs.

Stopped items must be routed back to Claude Code #1 or the user before any patch
is attempted.

## Evidence Contract

Every autonomous report or scoped PR must include:

- source Issue or PR number;
- changed-file scope;
- candidate evidence and stop reasons;
- required checks that must pass;
- explicit merge policy: `human_approval_required`.

The automation may comment with a low-risk review summary, but it never calls
`gh pr review --approve`, never merges, and never pushes to protected branches.

## Workflow

`Low-Risk PR Digestion` runs in two modes:

- scheduled queue scan: classify recent open PRs and Issues, then upload a
  Markdown/JSON artifact and write the job summary;
- manual single-PR scan: classify one PR and optionally comment the report on
  that PR.

The report complements `pr-review-routing.yml`: review routing handles existing
review comments, while low-risk digestion decides whether a small PR/Issue is
safe enough for autonomous attention.

## Local Commands

```powershell
python scripts\low_risk_pr_digest_test.py
$outMd = Join-Path $env:TEMP 'low-risk-pr-digest.md'
$outJson = Join-Path $env:TEMP 'low-risk-pr-digest.json'
python scripts\low_risk_pr_digest.py --repo kanta13jp1/my_web_app --max-prs 2 --max-issues 2 --output-md $outMd --output-json $outJson
```
