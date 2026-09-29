# Transaction Contract

## State machine

Use these checkpoint statuses in order where applicable:

1. `planned`: candidate selected but ownership not yet proven.
2. `in_progress`: scope owned and implementation or conflict resolution active.
3. `paused`: user or resource-pressure stop; no new heavy work may begin.
4. `blocked`: external state or an explicit decision is required.
5. `ready_to_push`: local checks and staged diff are proven.
6. `pushed`: remote branch SHA equals the intended local HEAD.
7. `ci_pending`: required checks are running or actionable failures remain.
8. `merge_ready`: exact head SHA is green and reviews permit merge.
9. `merged`: GitHub reports the PR merged and main contains the result.
10. `cleaned`: exact merged Worktree and local branch were safely removed.

Do not skip evidence merely to advance the status.

## Minimum checkpoint evidence

Store only secret-free summaries:

- Issue and PR numbers;
- Worktree absolute path, branch, HEAD, upstream drift, and dirty paths;
- completed validation commands and pass/fail results;
- local commits created;
- remote SHA confirmed after push;
- required check state;
- merged PR URL and merge time;
- unconfirmed operations after timeout or interruption;
- one exact next action.

Never store environment values, headers, JWTs, API keys, Stripe identifiers,
bank data, or copied command output that may contain credentials.

## Interruption rules

| Interrupted operation | Resume proof |
| --- | --- |
| `git commit` or hook | Inspect `HEAD`, staged status, process owners, and lock files. |
| `git push` or pre-push hook | Compare local HEAD with `git ls-remote` and PR `headRefOid`. |
| CI watch | Query current checks for the exact head SHA. |
| merge command | Query PR `state`, `mergedAt`, and merge result before retrying. |
| Worktree removal | Re-run `git worktree list`; never assume a partial removal. |
| PC-load pause | Re-audit worktree and remote state before any heavy command. |

An exit code, timeout, stale console output, or bot comment is not sufficient
proof by itself.

## Cleanup proof

Require all applicable facts:

- target is a registered non-primary Worktree;
- target path is exact and exists;
- status is clean, including untracked files;
- no merge, rebase, cherry-pick, sequencer, or index lock is active;
- expected local head matches;
- PR is merged with the same head branch and head SHA, or local HEAD is an
  ancestor of the freshly fetched base branch;
- no user-requested artifact remains only inside the target Worktree;
- checkpoint records the merge and cleanup decision.

The bundled checker proves Git facts but does not delete anything. Perform the
removal as a separate, explicit command and verify afterward.
