# OpenAI WIF security review runbook

## Decision

The Codex lane in `.github/workflows/high-risk-dual-security-review.yml` uses
GitHub Actions OIDC and OpenAI Workload Identity Federation (WIF). It must not
use a long-lived `OPENAI_API_KEY`. The Claude lane and decision-event service
keep their existing, separately scoped credentials.

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

Create one service-account mapping per trusted base branch. Each mapping must
contain all five exact claim assertions shown below.

### main

```text
iss = https://token.actions.githubusercontent.com
aud = https://api.openai.com/v1
repository = kanta13jp1/my_web_app
ref = refs/heads/main
workflow_ref = kanta13jp1/my_web_app/.github/workflows/high-risk-dual-security-review.yml@refs/heads/main
```

### staging

```text
iss = https://token.actions.githubusercontent.com
aud = https://api.openai.com/v1
repository = kanta13jp1/my_web_app
ref = refs/heads/staging
workflow_ref = kanta13jp1/my_web_app/.github/workflows/high-risk-dual-security-review.yml@refs/heads/staging
```

### develop

```text
iss = https://token.actions.githubusercontent.com
aud = https://api.openai.com/v1
repository = kanta13jp1/my_web_app
ref = refs/heads/develop
workflow_ref = kanta13jp1/my_web_app/.github/workflows/high-risk-dual-security-review.yml@refs/heads/develop
```

Do not replace these with a broad `repository_owner`-only assertion. Bind every
mapping to the dedicated project, service account, and `api.model.request`
permission.

## GitHub repository variables

Set these under repository **Settings → Secrets and variables → Actions →
Variables**. They identify WIF resources but are not bearer credentials.

```text
OPENAI_WIF_AUDIENCE=https://api.openai.com/v1
OPENAI_IDENTITY_PROVIDER_ID=<OpenAI provider ID>
OPENAI_SERVICE_ACCOUNT_ID=<OpenAI service account ID>
```

Do not add `OPENAI_API_KEY` for this workflow. GitHub supplies
`ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` only to the
job with `id-token: write`; the script never prints either token.

## Bootstrap and validation

The workflow definition used by `pull_request_target` comes from the trusted
base branch. Therefore the first PR that introduces WIF cannot exercise the
new WIF path before it is merged. Review and merge that bootstrap PR using the
normal repository-owner exception process after its deterministic tests pass.

After the workflow is on the base branch:

1. Configure the OpenAI project, service account, hard limit, provider, and
   branch mappings.
2. Set the three GitHub repository variables.
3. Re-run the high-risk review for PR #5015 with `workflow_dispatch`.
4. Confirm the PR comment contains executed Claude and Codex results, distinct
   evidence IDs, and one decision trace ID.
5. Confirm the OpenAI project usage increased by the expected single request
   and no credential or raw token appears in Actions logs.

Any missing variable, OIDC endpoint, review result, or decision-event write
continues to fail closed. Safe diagnostics retain an exception class and HTTP
status only; response bodies, headers, URLs with query strings, and tokens are
discarded.

## Revocation and recovery

To revoke access immediately, disable or delete the OpenAI service-account
mapping (or the dedicated service account). Then remove the three GitHub
repository variables. Do not fall back to a long-lived API key. Repair the WIF
configuration and re-run the failed workflow; prior unavailable evidence does
not count as an independent review.
