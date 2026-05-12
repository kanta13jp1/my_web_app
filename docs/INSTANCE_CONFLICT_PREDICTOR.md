# Instance Conflict Predictor

Issue: [#926](https://github.com/kanta13jp1/my_web_app/issues/926)

This runbook turns the NotebookLM "Harness Engineering" memo into a practical
guardrail for the 12-instance fleet: 10 Claude Code instances plus Codex #1 and
Codex #2. The predictor checks recent commits, open PRs, dirty local worktrees,
and Supabase migration timestamps before an instance starts work or stages a
risky change.

## Why This Exists

The fleet can move quickly only when ownership is visible. The failure modes are
usually boring but expensive:

- two instances edit the same hot file at the same time
- a draft PR touches the same file that a new worktree is about to edit
- a local dirty worktree hides changes that another instance cannot see
- two migrations claim the same timestamp or land too close together
- Slack, Notion, WBS, and GitHub drift apart after a handoff

The predictor is intentionally dependency-free Python so it can run from
PowerShell, Claude Code hooks, Codex sessions, GitHub Actions, and scheduled
jobs.

## Worktree Registry Preflight

Use [`docs/WORKTREE_REGISTRY.md`](WORKTREE_REGISTRY.md) before editing when a
task has an expected write scope. The registry records the owning instance,
issue, worktree, branch, and planned paths in a local gitignored JSON file.
That gives Claude Code #1 and Codex #1 an explicit ownership map before this
predictor scans commits, open PRs, dirty worktrees, and migration timestamps.

## Commands

Session start or handoff:

```powershell
python scripts\instance_conflict_predictor.py `
  --changed-from origin/main `
  --notify console `
  --json-out tmp\instance-conflict.json
```

Before staging files:

```powershell
python scripts\instance_conflict_predictor.py `
  --staged `
  --fail-on high `
  --notify console,slack `
  --json-out tmp\pre-add-conflict.json
```

Before creating a migration:

```powershell
python scripts\instance_conflict_predictor.py `
  --migration-timestamp 20260501090000 `
  --notify console `
  --json-out tmp\migration-conflict.json
```

Target an explicit file set:

```powershell
python scripts\instance_conflict_predictor.py `
  --files lib/pages/project_gantt_page.dart supabase/migrations/20260501090000_example.sql `
  --notify console,wbs `
  --json-out tmp\target-file-conflict.json
```

## Risk Levels

- **High**: an active local dirty worktree overlaps the target files, or a
  migration timestamp collision/cluster is detected. Stop and coordinate before
  `git add`.
- **Medium**: recent identified commits or open PRs overlap the target files.
  Rebase, inspect the related PR, or comment on the owning issue before pushing.
- **Low**: no detected overlap in the configured scan window. Continue with the
  normal lint/test gate.

## Notification Routes

`--notify` accepts a comma-separated list:

- `console`: prints a compact JSON summary
- `slack`: posts to `CONFLICT_PREDICTOR_SLACK_WEBHOOK`, falling back to
  `SLACK_WEBHOOK_URL`
- `notion`: marks the JSON output as ready for a Notion writer job
- `wbs`: marks the JSON output as ready for a WBS writer job

The script does not write directly to Notion/WBS because those tables need
schema-aware writers. Use `--json-out` as the stable handoff payload.

## GitHub Actions

`.github/workflows/instance-conflict-predictor.yml` runs the predictor on PRs
that touch the script, workflow, migrations, or this runbook. It also supports
manual dispatch for cross-instance audits. The workflow uploads both Markdown
and JSON reports as artifacts.

## Fleet Routing

- Claude Code instances own ambiguous design, review prompts, and hook policy.
- Codex #1 owns cross-cutting implementation and broad repo scans.
- Codex #2 owns CI repair, sync drift, Edge Functions, and deterministic
  automation.
- NotebookLM remains the external memory; repository checks remain the source of
  truth.

## Official Source Watch

Every session should keep using the existing AI tool watch loop:

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Claude Code GitHub Actions: https://code.claude.com/docs/en/github-actions
- Codex changelog: https://developers.openai.com/codex/changelog
- Codex use cases: https://developers.openai.com/codex/use-cases/

As of the 2026-05-01 session, the active adoption signals are Claude Code hook
and GitHub Actions quality gates plus Codex persistent workflow / parallel
execution improvements. The predictor is the repository-side guardrail for
those signals.
