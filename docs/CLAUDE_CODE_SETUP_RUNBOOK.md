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

## Session Compression Guard

`.claude/hooks/session-start-hard-gate.ps1` runs
`scripts/session_compression_guard.py --mode session-start` before the regular
state check. It emits a one-line KPI banner, appends forced cleanup fires to
`~/.claude/logs/session-delta.csv`, and writes cooldown state to
`~/.claude/state/session-compression-guard.json`.

Default behavior is safe for repo-managed hooks:

- SessionStart applies `scripts/dev_cache_cleanup.py --apply` when C: free
  space is below 26 GB or the last cleanup fire is older than 4 hours.
- SessionStart now passes `--always-fire --min-reclaim-mb 512` for the v27
  Layer DDD contract. It still exits zero by default, but the per-fire quota
  result is written to `~/.claude/logs/session-delta.csv`.
- PreToolUse runs `.claude/hooks/pretooluse-compression-budget.ps1`, increments
  a local tool-use counter, records every 10th-tool KPI snapshot, and runs a
  capped 30-second cleanup only when C: free space is below 22 GB. The per-session
  mid-fire cap is 5.
- UserPromptSubmit runs `.claude/hooks/userprompt-idle-gap-fire.ps1` after the KPI
  banner. It applies a 30-minute idle-gap cleanup with a 60-minute cooldown.
- Stop runs `.claude/hooks/session-end-auto-compress.ps1` as the repo-managed
  SessionEnd/wrap-up compression primitive. It is advisory unless
  `SESSION_COMPRESSION_WRAPUP_ENFORCE=1` is set.
- Stop also records the v27 DDD 512 MB reclaim quota. Set
  `SESSION_COMPRESSION_WRAPUP_ENFORCE=1` only after confirming local cleanup can
  meet the quota without trapping the host shell.
- SessionStart runs `.claude/hooks/smartcleanup-monthlydeep-guard.ps1` as the
  v27 Layer GGG guard. It detects `SmartCleanup_MonthlyDeep` missing/stuck
  states, including `LastTaskResult=267011` and 1999-era `LastRunTime` sentinel
  values. It reports by default; set `SMARTCLEANUP_MONTHLYDEEP_FIX=1` to start
  the task on demand, and `SMARTCLEANUP_MONTHLYDEEP_ENFORCE=1` to fail closed.
- It exits zero by default so an unavailable Python runtime or a missed 28 GB
  target does not trap a user in a broken local shell.
- Set `SESSION_COMPRESSION_FAIL_CLOSED=1` to enforce the 28 GB target and return
  a non-zero exit when cleanup fails or the target is still missed.
- Set `SESSION_COMPRESSION_WRAPUP_ENFORCE=1` to make the wrap-up compression
  primitive fail closed when the 28 GB target is missed.
- Set `SESSION_COMPRESSION_DRY_RUN=1` while validating hook wiring without
  pruning caches.

`.claude/hooks/userprompt-kpi-banner.ps1` runs on `UserPromptSubmit` and emits
the same `[KPI] C:<gb> RAM:<pct> last_fire:<min> fatigue:<state>` advisory. It
does not run cleanup unless `SESSION_COMPRESSION_USERPROMPT_APPLY=1` is set,
which keeps ordinary prompt entry lightweight while preserving the v23 idle-gap
escape hatch.

Manual verification examples:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\pretooluse-compression-budget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\smartcleanup-monthlydeep-guard.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\userprompt-idle-gap-fire.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\session-end-auto-compress.ps1
python scripts\session_compression_guard_test.py
python scripts\smartcleanup_task_guard_test.py
python scripts\check_session_state_hooks.py --scan-transcripts
```

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
python scripts/session_compression_guard_test.py
python scripts/codex_session_check.py --json
git diff --check
```

CI verification:

- `.github/workflows/session-state-hooks.yml`
- `.github/workflows/codex-session-safety-cron.yml`
