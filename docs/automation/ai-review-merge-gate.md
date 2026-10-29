# PR-visible bridge for trusted AI review evidence

Refs #4744. PR #5926 had successful CI and genuine trusted AI approval on its
exact head/base, but the Checks API record was absent from the PR rollup and
normal protected merge remained blocked. One fresh main-dispatched review
reproduced this; repeatedly requesting reviews is not a recovery strategy.

`ai-review-merge-gate.yml` adds a real pull-request job named `AI Review Gate`.
It does not alter branch protection, approval policy, the trusted reviewer,
provider credentials, paid-model policy, or deployment authority. Its token
has read-only permissions; it neither publishes review results nor merges.

The job requires the latest matching GitHub Actions review check, successful
execution of the existing trusted `claude-agent-review.yml`, and its own
nonexpired evidence artifact. It verifies repository, PR, immutable head/base,
trusted workflow source SHA, run/attempt/check identifiers, complete-diff
approval, actual provider response, review binding/digest, and no blocking
findings. It never substitutes a skipped job, fabricated approval, older run,
different workflow, or green build for actual review evidence.

Only unfinished remote review work is polled, for at most 15 minutes on the
GitHub-hosted runner. Rejection, invalid/missing evidence after completion,
API failure, PR drift, or timeout fail closed. ZIP evidence is size-limited,
read in memory, and never extracted. Offline regression tests run first in CI.
No local Flutter dependency hydration, test, or build is required.
