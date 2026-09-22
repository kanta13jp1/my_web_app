# OpenAI WIF security review runbook

## Decision

The Codex lane in `.github/workflows/high-risk-dual-security-review.yml` uses
GitHub Actions OIDC and OpenAI Workload Identity Federation (WIF). It must not
use a long-lived `OPENAI_API_KEY`. The Claude lane and decision-event service
keep their existing, separately scoped credentials.

As of 2026-08-30, the owner has suspended all paid Claude/Codex automation
until this repository has zero open GitHub Issues. Repository variable
`PAID_AI_CLAUDE_CODEX_ENABLED` must remain `false`, and credential-bearing
workflows remain manually disabled during the rollout. Credentials and WIF
mappings are retained for later recovery; they are not exposed to workflow
steps while the policy is disabled.

The reusable `.github/actions/paid-ai-policy` gate requires both an explicit
owner opt-in and a live open-Issue count of zero. Any lookup error disables the
paid path. Reaching zero Issues never changes the variable automatically.

OpenAI references:

- [GitHub Actions workload identity federation](https://developers.openai.com/api/docs/guides/workload-identity-federation/github-actions)
- [Project spend limits](https://developers.openai.com/api/docs/guides/spend-limits)

## OpenAI project controls

Create a dedicated OpenAI project and service account for this workflow.

- Project name: `my-web-app-high-risk-security-review`
- Service account name: `github-high-risk-dual-review`
- Mapping permission: `api.model.request` only
- Monthly project hard spend limit: **$10 USD**
- Spend alerts: **50% ($5)** and **80% ($8)**

The hard limit is the enforcement control; alerts alone do not stop usage.
OpenAI notes that enforcement is not instantaneous, so keep the workflow's
240,000-byte input cap, 2,500 output-token cap, and 15-minute timeout in place.

## Workload Identity Provider

Create one OpenAI Workload Identity Provider with:

- OIDC issuer URL: `https://token.actions.githubusercontent.com`
- Audience: `https://api.openai.com/v1`
- Uploaded JWKS: disabled; use GitHub OIDC discovery

GitHub currently evaluates `pull_request_target` in the repository default
branch context. This workflow therefore supports `main` only. Do not create
equivalent mappings for `staging` or `develop`: a less-protected base branch
must never be able to run code with the default-branch OIDC identity.

Create two service-account mappings. Bind both mappings to the dedicated
project and service account, and grant `api.model.request` only.

### Automatic trusted-author PR review

```text
iss = https://token.actions.githubusercontent.com
aud = https://api.openai.com/v1
repository = kanta13jp1/my_web_app
ref = refs/heads/main
workflow_ref = kanta13jp1/my_web_app/.github/workflows/high-risk-dual-security-review.yml@refs/heads/main
environment = high-risk-security-review
event_name = pull_request_target
base_ref = main
```

### Explicit maintainer dispatch

```text
iss = https://token.actions.githubusercontent.com
aud = https://api.openai.com/v1
repository = kanta13jp1/my_web_app
ref = refs/heads/main
workflow_ref = kanta13jp1/my_web_app/.github/workflows/high-risk-dual-security-review.yml@refs/heads/main
environment = high-risk-security-review
event_name = workflow_dispatch
```

Do not replace these assertions with a broad `repository_owner`-only mapping.

## GitHub environment and external-contributor gate

Create the GitHub environment `high-risk-security-review` and allow deployment
from `main` only. Move these credentials into that environment, then remove
their repository-level copies:

```text
ANTHROPIC_API_KEY
SUPABASE_SERVICE_ROLE_KEY
```

Only PR authors associated as `OWNER`, `MEMBER`, or `COLLABORATOR` run the
credential-bearing review automatically. Every other author fails closed
without receiving model or Supabase credentials. After inspecting the exact PR
diff, a maintainer can approve that review by dispatching this workflow from
`main` with the PR number. In the repository Actions settings, require approval
for all outside collaborators as an additional defense against unrelated fork
workflows.

## GitHub repository variables

Set these under repository **Settings → Secrets and variables → Actions →
Variables**. They identify WIF resources but are not bearer credentials.

```text
PAID_AI_CLAUDE_CODEX_ENABLED=false
OPENAI_WIF_AUDIENCE=https://api.openai.com/v1
OPENAI_IDENTITY_PROVIDER_ID=<OpenAI provider ID>
OPENAI_SERVICE_ACCOUNT_ID=<OpenAI service account ID>
```

Do not add `OPENAI_API_KEY` for this workflow. GitHub supplies
`ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` only to the
job with `id-token: write`; the script never prints either token.

## Python dependency lock

The credential-bearing job uses CPython 3.12 and installs only prebuilt wheels
whose complete dependency graph and SHA-256 hashes are recorded in
`scripts/requirements-high-risk-security-review.txt`. A top-level OpenAI SDK
version pin alone is not sufficient because its transitive dependencies use
version ranges.

Regenerate the lock in an empty directory and review every version and hash:

```powershell
python -m pip download --disable-pip-version-check --no-cache-dir `
  --only-binary=:all: --platform manylinux2014_x86_64 `
  --python-version 312 --implementation cp --abi cp312 `
  --dest <empty-directory> "openai==3.6.0"
Get-FileHash -Algorithm SHA256 <empty-directory>\*.whl
```

Update the lock through a reviewed PR. CI re-downloads the Linux CPython 3.12
wheels with `--require-hashes`; the production job installs with the same hash
enforcement.

## Bootstrap and validation

The workflow definition used by `pull_request_target` comes from the trusted
base branch. Therefore the first PR that introduces WIF cannot exercise the
new WIF path before it is merged. Review and merge that bootstrap PR using the
normal repository-owner exception process after its deterministic tests pass.
Record the non-executed Claude ownership path in the PR body with the gate's
exact `Reviewer: Claude Code #1` and `High-Risk-Ultrareview-Exception:` fields;
do not represent the exception as a completed independent review.

After the workflow is on the base branch:

1. Configure the OpenAI project, service account, hard limit, provider, and
   the two `main` mappings.
2. Create the protected GitHub environment, move the two existing credentials
   into it, and remove their repository-level copies.
3. Set the three GitHub repository variables and require approval for all
   outside collaborators in the repository Actions settings.
4. Re-run the high-risk review for PR #5015 from `main` with
   `workflow_dispatch`.
5. Confirm the PR comment contains executed Claude and Codex results, distinct
   evidence IDs, and one decision trace ID.
6. Confirm the OpenAI project usage increased by the expected single request
   and no credential or raw token appears in Actions logs.

When paid review is enabled, any missing variable, OIDC endpoint, review
result, or decision-event write continues to fail closed. While owner policy
is disabled, the workflow records an explicit non-review exception and does
not enforce or misrepresent dual-model evidence. Safe diagnostics retain an
exception class and HTTP status only; response bodies, headers, URLs with query
strings, and tokens are discarded.

## Manual reactivation after Issues=0

Do not automate these steps. The owner must perform and review them in order:

1. Confirm `repo:kanta13jp1/my_web_app is:issue is:open` returns `0`.
2. Confirm the dedicated OpenAI hard spend limit and Anthropic billing controls
   still match the approved budget.
3. Set `PAID_AI_CLAUDE_CODEX_ENABLED=true`.
4. Re-enable only the required workflows, starting with a single manual run.
5. Verify the gate summary says `enabled-after-issues-zero` before accepting
   any model result.

If open Issues rise above zero later, the live gate blocks new paid requests
even while the variable remains true. Set the variable back to `false` as the
owner-visible durable state.

## Revocation and recovery

To revoke access immediately, disable or delete the OpenAI service-account
mapping (or the dedicated service account). Then remove the three GitHub
repository variables. Do not fall back to a long-lived API key. Repair the WIF
configuration and re-run the failed workflow; prior unavailable evidence does
not count as an independent review.
