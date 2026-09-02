---
name: github-issue-completion-forecast
description: After completing work on a GitHub Issue, report the repository's current open-Issue count, recent completion throughput, and a data-backed all-Issues completion forecast. Use at every Issue completion or completion handoff; do not use for ordinary progress updates.
---

# GitHub Issue Completion Forecast

Use this skill after finishing an Issue lane, including when implementation is
complete but the Issue intentionally remains open for review, deployment, or
measurement. Never describe an open Issue as closed.

## Generate a fresh forecast

Run the bundled read-only reporter from the repository root:

```powershell
python .agents/skills/github-issue-completion-forecast/scripts/issue_completion_forecast.py --completed-issue <number>
```

Pass `--repo owner/name` outside the target repository. The script obtains the
current open count and 7-day/30-day closed-Issue totals directly from GitHub.
Do not reuse a count or ETA from an earlier completion.

If GitHub authentication, repository resolution, or the search API fails,
report that the forecast could not be refreshed and include the concrete
failure. Do not substitute a remembered count.

## Completion reporting contract

Include the generated `Issue backlog forecast` block in the user-facing
completion response. When an authorized Issue completion comment is already in
scope, include the same block there. This skill does not itself authorize
closing an Issue, editing a comment, or performing any other GitHub mutation.

Keep these fields visible:

- completed Issue number and its current OPEN/CLOSED state;
- current open-Issue count;
- closed Issues and average completions/day for the last 7 and 30 days;
- all-Issues completion forecast in JST;
- confidence and forecast assumptions.

The reporter uses the 30-day observed closure rate and assumes no new Issues and
unchanged throughput. Treat the result as a capacity forecast, not a deadline.
If the 30-day sample is below the minimum, show `算出保留` rather than inventing
precision. If the completed Issue remains OPEN, explicitly say that the current
open count still includes it.

## Verification

Before reporting, confirm the command exited successfully and the timestamp is
from the current run. Keep raw search results and personal data out of comments;
only the aggregate counts and forecast are needed.
