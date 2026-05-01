# Codex CLI 0.128.0 `/goal` Workflows Evaluation

Issue: https://github.com/kanta13jp1/my_web_app/issues/1492

Source checked on 2026-05-01:

- OpenAI Codex release `rust-v0.128.0`
- Local CLI probe: `codex --version` -> `codex-cli 0.126.0-alpha.8`
- Local CLI probe: `codex --help`

## Decision

**NO-GO for immediate fleet adoption. GO for tracked pilot after Codex CLI upgrade.**

The release is highly relevant to Codex #2 because persisted `/goal` workflows
map directly to long-running CI, synchronization, Edge Function, and GitHub
Actions tasks. The local runtime is still older than 0.128.0, so this session
cannot prove the feature with a live `/goal` run.

## Why It Matters

Codex #2 currently handles work that often spans multiple checks or sessions:

- red CI investigation and reruns,
- deploy stability and workflow drift,
- Edge Function dependency and lint repair,
- scheduled report/watch maintenance,
- GitHub issue and WBS synchronization.

Those are good candidates for persisted goals because the task state should
survive pauses, context compaction, and multi-step verification.

## Adoption Gate

Adopt `/goal` workflows only when all of these are true:

- `codex --version` is `0.128.0` or newer on the target Codex instance.
- `codex --help` exposes `/goal` or the matching app-server goal APIs in the
  installed runtime.
- A pilot goal can be paused, resumed, and cleared without losing the linked
  branch, issue, PR, and validation checklist.
- A failed or abandoned goal leaves a deterministic handoff in GitHub issue or
  `docs/cross-instance-prs/`.

## Pilot Candidates

| Candidate | Owner | Fit | Notes |
| --- | --- | --- | --- |
| CI failure drain | Codex #2 | High | Keep failing check, log URL, local branch, fix attempt, and rerun status in one persisted goal. |
| Edge Function dependency audit | Codex #2 | High | Long enough to benefit from pause/resume; deterministic lint/check proof. |
| Mobile release artifact rollout | Codex #2 | Medium | Useful after Android/iOS signing secrets exist. |
| Migration collision review | Codex #1 | Medium | Better for Codex #1 unless CI workflow repair is involved. |

## Proposed First Pilot

Use the next failing PR check as the first pilot:

1. Create a `/goal` named `codex2-ci-failure-drain`.
2. Store PR URL, failing check URL, branch, suspected owner, and next command.
3. Pause after the first root-cause note.
4. Resume in a fresh session and verify the state is enough to continue.
5. Clear the goal only after PR checks pass or a handoff comment is posted.

Success means the resumed session avoids re-reading the whole PR/check context
and still performs deterministic validation before handoff or merge.

## Workflow/Docs Changes

Implemented in this evaluation PR:

- `scripts/codex_session_check.py` now prints the local Codex CLI version.
- The same session-start check warns when Codex CLI is older than 0.128.0,
  because persisted `/goal` workflows are not ready on older runtimes.

Recommended after upgrade:

- Add a short `/goal` usage note to `AGENTS.md` after the runtime is upgraded.
- Add a scheduled issue comment or WBS update when a persisted goal is older
  than 24 hours without progress.

## Current Blockers

- Local runtime is `codex-cli 0.126.0-alpha.8`, below the evaluated release.
- No live `/goal` command was available to prove pause/resume behavior in this
  session.
- App-server API integration details should be rechecked after the local CLI
  upgrade because the feature is new and may change quickly.

## Final Routing

- Keep issue #1492 open until the local Codex #2 runtime is upgraded and one
  pilot goal is completed.
- Route upgrade execution and app-server checks to Codex #2.
- Route broader fleet policy changes to Claude Code after the pilot.
