# Claude Code Setup Runbook

Status: repo-managed runbook for Issue #1564.

This document separates one-time setup from recurring maintenance for the
two-instance fleet: Claude Code #1 and Codex #1. It also documents where
session memory is stored and how secrets are kept out of committed recovery
artifacts.

## Scope

- Active instances: Claude Code #1 and Codex #1 only.
- Dormant lanes: old Codex #2/#3 and historical PS instance lanes stay inactive.
- Repo-managed hooks live under `.claude/hooks/`.
- User-home hooks such as `~/.claude/settings.json` must be changed manually by
  the owner when needed; this repo ships the command and verification contract.

## `--init` One-Time Setup

Run these when preparing a new Windows instance or recreating a broken local
setup.

1. Clone or fetch the repository.
   `git clone https://github.com/kanta13jp1/my_web_app.git`
2. Create an isolated worktree for the active instance.
   `git worktree add C:\Users\kanta\GitHub\my_web_app_<name> -b codex1/<name> origin/main`
3. Confirm the fleet rule in the first session message.
   `Claude Code #1 + Codex #1 only; no old Codex #2/#3 lanes.`
4. Verify repo-managed settings and hooks.
   `python scripts/check_session_state_hooks.py`
5. Run the session state check.
   `python scripts/codex_session_check.py --json`
6. Seed optional local markers for faster recovery.
   `memory/active-issue.txt` contains one issue number, for example `1564`.
   `memory/next-quality-gate.txt` contains the next command to run.
7. Validate the worktree before edits.
   `git status --short --branch`

## `--maintenance` Recurring Maintenance

Run these at the beginning or end of long sessions, and before handing the
thread to the next session.

1. Check C: drive capacity and top memory consumers.
2. Check the current branch, upstream, dirty paths, and worktree list.
3. Run `python scripts/codex_session_check.py --json`.
4. Run `python scripts/check_session_state_hooks.py`.
5. Prune only safe Git metadata.
   `git remote prune origin`
   `git worktree prune`
   `git gc --auto`
6. Consider cache cleanup.
   Prefer `scripts/dev_cache_cleanup.py --dry-run` first when available.
   Apply only when it does not interfere with active VSCode, Dart, Deno, or MCP
   parent processes.
7. Record executed and skipped compression actions in the wrap-up.

## PreCompact Recovery

`.claude/hooks/pre-compact-backup.ps1` writes redacted recovery files to
`memory/transcripts/compact-<timestamp>.md`.

Each backup starts with YAML frontmatter:

- `saved_at`
- `instance`
- `two_instance_policy`
- `worktree`
- `branch`
- `head_sha`
- `in_progress_issue`
- `active_pr`
- `next_quality_gates`
- `uncommitted_files`
- `unpushed_commits`

At the next session start, read the newest `memory/transcripts/compact-*.md`,
then run `python scripts/codex_session_check.py --json` before editing.

## SessionStart Recovery

`.claude/hooks/session-start-state-check.ps1` logs deterministic checks to
`memory/session-start-check/session-start-<yyyymmdd>.log`.

The hook checks:

- Branch prefix against the active two-instance policy.
- Old dormant branch prefixes such as `codex2/` and `codex3/`.
- Upstream ahead/behind status.
- Dirty paths.
- Unpushed commits.
- The next quality gate marker.
- `scripts/codex_session_check.py --json` output.

The hook never blocks the host session. Warnings are written to the log so the
agent can recover the state in under one minute after context compaction.

## StatusLine

The repo-managed status line command is:

`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/statusline.ps1`

It displays:

- Instance (`win-claude`, `win-codex`, or `unknown`).
- Active issue from `memory/active-issue.txt`.
- Branch and dirty path count.
- Next quality gate from `memory/next-quality-gate.txt`.

If a user-home Claude Code config is needed, copy the repo command into
`~/.claude/settings.json` after confirming that it points at the intended
worktree.

## Secret Handling

Allowed committed files:

- `memory/transcripts/.gitkeep`
- Redacted compact backups produced by the hook when they contain no secrets.

Local-only ignored files:

- `memory/session-start-check/*.log`
- `memory/transcripts/compact-*.md`

Optional local marker files:

- `memory/active-issue.txt`
- `memory/next-quality-gate.txt`

These marker files are read when present. Keep them local unless a PR explicitly
needs a fixture.

Never commit:

- `.env`
- Raw GitHub PATs.
- Bearer tokens.
- API keys.
- Session cookies.
- NotebookLM storage state.
- Any compact backup that contains an unredacted secret.

The redaction filter handles common GitHub token, Bearer token, `sk-*`, `sb_*`,
and `PASSWORD` / `SECRET` / `TOKEN` / `KEY` assignment patterns. The CI check
`scripts/check_session_state_hooks.py --scan-transcripts` blocks known secret
patterns under `memory/transcripts/`.

## Verification

Local verification:

```powershell
python scripts/check_session_state_hooks.py
python scripts/codex_session_check.py --json
git diff --check
```

CI verification:

- `.github/workflows/session-state-hooks.yml`
- `.github/workflows/codex-session-safety-cron.yml`
