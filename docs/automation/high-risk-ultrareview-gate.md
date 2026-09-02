# High-Risk Ultrareview Gate

Issue: #1569

This gate supports the current two-instance operating model:

- Claude Code #1 owns high-risk review judgment, exception policy, and any
  manual `/ultrareview` run.
- Codex #1 owns deterministic GitHub Actions wiring, tests, and scoped PRs.

The workflow does not start extra agents. It detects high-risk PRs and requires
the PR body to record Claude Code #1 ultrareview evidence or a visible exception
reason before merge checks can pass.

## High-Risk Triggers

The gate treats a PR as high-risk when it sees any of these signals:

- labels such as `security`, `supabase`, `edge-function`, `workflow-failure`,
  `priority:critical`, `deploy`, or `production`;
- database migrations, Supabase Edge Functions, auth/billing/payment code,
  production deploy workflows, Firebase config, secrets, credentials,
  `service_role`, or RLS paths;
- PR title/body keywords for secrets, credentials, tokens, auth, billing,
  production deploy, migrations, RLS, or service-role access.

## PR Body Contract

For high-risk PRs, include a section like this:

```markdown
## High-risk Ultrareview Gate
- Reviewer: Claude Code #1
- Evidence: Claude ultrareview completed for PR #123.
- Perspectives covered: security, rollback, data migration, prod smoke, observability.
- Unresolved findings: none.
```

If ultrareview cannot be run before merge, the exception must be visible in the
PR body:

```markdown
## High-risk Ultrareview Gate
- Reviewer: Claude Code #1
- High-Risk-Ultrareview-Exception: workflow-only bootstrap; owner accepted follow-up review after merge.
```

Empty placeholders and hidden comments do not satisfy the gate.

## Ready-to-paste blocks

AI authors create PR bodies with `gh pr create --body`, which bypasses the PR
template, and the gate also fires on PR *prose* (the words `deploy`, `billing`,
`migration`, and so on), so a body can trip the gate even when no high-risk path
is touched. Because editing a PR body does not re-run the check, the usual
recovery is a wasteful close/reopen. Emit the exact passing block from the
checker instead and paste it verbatim:

```bash
# Honest route when /ultrareview was NOT run (e.g. prose-only trigger):
python scripts/check_high_risk_ultrareview_gate.py \
  --emit-exception "prose-only trigger; no high-risk path touched, review after merge"

# Evidence route — only after Claude Code #1 actually ran /ultrareview:
python scripts/check_high_risk_ultrareview_gate.py --emit-evidence
```

The wording lives in `passing_exception_block()` / `passing_evidence_block()`
next to the pattern tables they must satisfy, and the perspective list is
derived from `REQUIRED_PERSPECTIVES`, so a round-trip test in
`check_high_risk_ultrareview_gate_test.py` pins both against the validator — they
cannot silently drift. When a local `--body-file` check FAILs, the exception
block is printed under a `snippet start/end` banner so the fix is one copy away.

Do not paste the evidence block unless a real `/ultrareview` run happened;
claiming review evidence that was not produced defeats the gate. When in doubt,
use the exception route and name the follow-up plan.

## Ultrareview cannot run in CI — run it locally

Do not spend time trying to make the `Claude ultrareview (opt-in)` job in
`.github/workflows/claude-agent-review.yml` produce evidence. It has been
investigated to exhaustion (2026-07-27/28) and the launch is refused from the
GitHub Actions runner:

```
Ultrareview could not launch: Ultrareview is currently unavailable.
```

Every competing explanation was eliminated by measurement, so **the evidence
route is satisfied by running ultrareview locally, not by CI**:

| Hypothesis | Verdict | Evidence |
| --- | --- | --- |
| Credential tier too low (API key) | Refuted | A subscription `CLAUDE_CODE_OAUTH_TOKEN` reproduces it exactly |
| Stored token invalid/revoked | Refuted | The pre-flight probe passes in CI, where there is no keychain to fall back to |
| Organization policy | Refuted | That case has its own message ("Cloud sessions are disabled by your organization's policy") and is not what we get |
| Overage / quota block | Refuted | Those have their own `blocked` / `needs-confirm` paths |
| Service-wide outage | Refuted | The same command succeeds locally |
| **GitHub Actions runner environment** | **Remaining** | Local succeeds, CI fails, with the same valid credential |

The job is still wired correctly and is left in place: if cloud sessions ever
become launchable from CI it will work unchanged. It fails loudly and never
posts a comment unless a review actually ran.

### Reading the job's failure

The job distinguishes three outcomes, so a red run should not be re-diagnosed
from scratch:

- **Credential check fails** — the configured secret is bad; re-issue with
  `claude setup-token` and update `CLAUDE_CODE_OAUTH_TOKEN`.
- **Credential check passes, ultrareview will not launch** — the known
  environment limitation above. Run it locally instead.
- **Both pass** — findings are posted to the PR.

Note `claude auth status` is *not* a credential check: it reports
`"loggedIn": true` even for a completely invalid token. Nor is a local
`claude -p` call, which silently falls back to the keychain session when the
configured token is bad. Only the CI-side probe isolates the credential.

### Producing evidence for a high-risk PR

```bash
claude ultrareview <PR#>
```

Runs in the cloud, takes about 5-10 minutes, and prints the findings. **The free
tier is limited (the CLI prints e.g. `Free ultrareview 2 of 3`)**, which is a
further reason the gate is manual rather than fired on every high-risk PR. Only
after a real run, record it with `--emit-evidence`.

## Local Verification

```powershell
python scripts\check_high_risk_ultrareview_gate_test.py
python scripts\check_high_risk_ultrareview_gate.py --body-file .\tmp-pr-body.md --changed-files .\tmp-changed-files.txt
```
