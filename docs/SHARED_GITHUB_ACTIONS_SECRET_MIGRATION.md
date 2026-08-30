# Shared GitHub Actions secret migration runbook

## Scope and current state

Issue #5019 migrates `ANTHROPIC_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY`
away from repository-level GitHub Actions secrets. The source-controlled
inventory is `.github/privileged-workflow-credentials.json`.

As of 2026-08-30, the operational inventory has 11 workflow files that resolve
`ANTHROPIC_API_KEY`, 55 that resolve `SUPABASE_SERVICE_ROLE_KEY`, and 61 unique
consumer workflows. The migration control workflow adds one source consumer
and nine credential-canary jobs; it is tracked separately from the operational
consumer count. The issue body's earlier 10 / 52 snapshot must not be used as
a deletion gate.

The repository copies are intentionally retained during the first migration
phase. An environment declaration alone does not isolate a job while a
same-named repository secret still exists. Internal branches can use repository
secrets, so deterministic internal-PR isolation is complete only after both
repository copies are deleted.

## Paid AI review pause

Paid OpenAI and Anthropic execution is paused while the repository has open
Issues. Both review workflows are disabled in GitHub. The canonical
`.github/actions/paid-ai-policy` action also requires the repository variable
`PAID_AI_CLAUDE_CODEX_ENABLED` to equal `true` and verifies that the live open
Issue count is zero before exposing paid credentials. Lookup errors fail
closed. Keep the variable set to `false` during the pause.

Do not re-enable the workflows or set the variable to `true` until all of the
following are true:

1. The repository open Issue count is zero.
2. The repository owner explicitly approves renewed OpenAI and Anthropic
   billing.
3. Provider credentials, WIF configuration, monthly spend limits, and review
   policy have been revalidated.

Run `python scripts/paid_ai_policy.py audit --workflows-dir
.github/workflows` to verify the paid-AI contract. The CI workflow runs the
same audit. Skipped or unavailable paid reviews during the pause are not valid
review evidence.

GitHub's [secrets reference](https://docs.github.com/en/actions/reference/security/secrets)
defines environment-over-repository precedence and when each secret scope is
read. GitHub's [environment reference](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
defines the pre-run protection gate, and the
[secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use)
states that repository write access permits use of repository secrets.

## Trust boundaries

| Environment | Boundary and purpose | Planned credential reduction |
| --- | --- | --- |
| `high-risk-security-review` | Trusted default-branch `pull_request_target` and maintainer dispatch | Dedicated Anthropic project; append-only decision-event token |
| `ai-review-production` | Main-only maintainer dispatch; PR diff is data, never executed | Dedicated Anthropic review project and spend cap |
| `ai-operations-production` | Main schedule, workflow completion, or maintainer dispatch | Dedicated Anthropic operations project and spend cap |
| `content-automation-production` | Main schedule/push or maintainer dispatch | Content/growth hub token; no database-wide bypass |
| `analytics-production` | Main schedule or maintainer dispatch | Read-only reporting views plus bounded result-write RPC |
| `customer-operations-production` | Default-branch issue event or maintainer dispatch | Customer-operation RPC allowlist |
| `platform-security-production` | Main security audit/remediation automation | Separate audit-read and explicit remediation tokens |
| `observability-production` | Main health, quota, release, and smoke automation | Health views plus run-result write RPC |
| `wbs-automation-production` | Default-branch issue/push/schedule/dispatch automation | WBS and synchronization RPC allowlist |

Every environment must use a custom deployment branch policy containing only
the `main` branch. Credential-bearing jobs use an environment mapping with
`deployment: false`; branch and reviewer protection still apply without adding
non-deployment automation to deployment history. Do not let a workflow
auto-create an unprotected environment.

## Phase 1: inventory and environment declarations

1. Run `python scripts/check_privileged_workflow_credentials.py`.
2. Review every workflow assignment and least-privilege target in the manifest.
3. Create all missing environments before merging the declarations.
4. Configure a custom `main` branch policy on each environment.
5. Keep the repository copies until the validation ledger is complete.

Create or update one environment with GitHub CLI after authenticating as a
repository administrator:

```powershell
$repo = 'kanta13jp1/my_web_app'
$environment = 'content-automation-production'
$encoded = [uri]::EscapeDataString($environment)
gh api --method PUT "repos/$repo/environments/$encoded" `
  --input environment-policy.json
gh api --method POST "repos/$repo/environments/$encoded/deployment-branch-policies" `
  -f name=main -f type=branch
```

Use an `environment-policy.json` file containing:

```json
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
```

Verify instead of assuming:

```powershell
gh api "repos/$repo/environments/$encoded"
gh api "repos/$repo/environments/$encoded/deployment-branch-policies"
```

## Phase 2: provision and validate environment credentials

GitHub never returns secret values. Obtain the current credential from the
approved password manager or rotate it at the provider; do not copy values from
logs, workflow files, shell history, or Actions artifacts.

While the paid AI policy is paused, do not purchase or rotate into additional
Anthropic/OpenAI capacity, call a paid provider, or dispatch a paid review
workflow. Relocating the already-approved Anthropic key from the protected
`high-risk-security-review` Environment into the other declared Environments
is allowed only through the migration control below. Relocation does not
enable provider access: `PAID_AI_CLAUDE_CODEX_ENABLED=false` continues to blank
the key in every paid consumer, including the quota monitor.

### Cloud-only provisioning control

Use `.github/workflows/shared-secret-environment-migration.yml` after it is
merged to `main`. It reads both source values from the protected
`high-risk-security-review` Environment, sends them to `gh secret set` over
standard input, and re-encrypts them directly into each target Environment.
The values are never returned to the operator, written to an artifact, or
placed in a command-line argument. `BYPASS_RULES` supplies the administrator
token required by GitHub's Environment secrets API.

Dispatch as the repository owner from `main`:

```powershell
$repo = 'kanta13jp1/my_web_app'
gh workflow run shared-secret-environment-migration.yml --repo $repo --ref main `
  -f mode=provision `
  -f 'confirmation=PROVISION ENVIRONMENT SECRETS'
```

The provisioning run must succeed before validation. A permission or partial
copy failure is fail-closed: do not delete either repository secret. Re-run
`provision` after repairing the administrator token; overwriting the same
Environment secret is safe.

For emergency interactive recovery only, set a same-named Environment secret
from the approved password manager or a newly rotated provider credential:

```powershell
gh secret set ANTHROPIC_API_KEY --env ai-review-production --repo $repo
gh secret set SUPABASE_SERVICE_ROLE_KEY --env content-automation-production --repo $repo
```

For each consumer, dispatch from `main` with the safest available dry-run input.
Record the environment, workflow path, run URL, commit SHA, result, external
write behavior, and rollback owner in the Issue #5019 validation ledger. A
scheduled run counts only when it is linked to the same reviewed commit.

Do not bulk-dispatch all workflows. Validate one environment group at a time and
stop on the first credential, permission, rate-limit, or output difference.

The migration control provides a non-mutating credential canary for all nine
Environments. Anthropic validation checks only that the Environment secret
resolves and never contacts Anthropic. Supabase validation performs an
authenticated `GET /rest/v1/` and reads one response byte; it does not query or
write a table.

```powershell
gh workflow run shared-secret-environment-migration.yml --repo $repo --ref main `
  -f mode=validate `
  -f 'confirmation=VALIDATE ENVIRONMENT SECRETS'
```

Record the provisioning and validation run URLs in Issue #5019 before either
deletion mode is dispatched.

## Phase 3: replace Supabase service-role use

Prefer an authenticated Edge Function or database RPC that exposes only the
operation the workflow needs. The replacement token must be project-specific,
audience-bound, revocable independently, and unable to bypass unrelated RLS.

For direct REST calls:

1. List the exact tables, views, columns, filters, and write operations.
2. Create a dedicated database role or RPC with only those grants.
3. Add RLS or explicit authorization checks; service-role semantics are not a
   substitute for an authorization design.
4. Change one workflow group to the scoped token name from the inventory.
5. Validate success, denied unrelated access, timeout, missing credential, and
   provider-revocation paths.

Keep a service-role exception only when the operation truly needs RLS bypass.
Record the workflow, reason, data scope, approver, expiration/review date, and
rotation owner. Store the exception credential in its declared environment.

## Phase 4: deletion and deterministic proof

Delete a repository secret only after every listed consumer has a successful
validation entry and the static checker is green. Delete one secret at a time:

```powershell
gh secret delete ANTHROPIC_API_KEY --repo $repo
gh secret list --app actions --repo $repo
```

Immediately verify that the deleted name is absent from the repository secret
listing, then re-run every Anthropic consumer group from `main`. Repeat the same
process for `SUPABASE_SERVICE_ROLE_KEY` only after all scoped-token replacements
and approved service-role exceptions are green.

The owner-confirmed cloud deletion controls validate all Environment secrets
again before deleting one repository copy:

```powershell
gh workflow run shared-secret-environment-migration.yml --repo $repo --ref main `
  -f mode=delete-anthropic `
  -f 'confirmation=DELETE REPOSITORY ANTHROPIC_API_KEY'

gh workflow run shared-secret-environment-migration.yml --repo $repo --ref main `
  -f mode=delete-supabase `
  -f 'confirmation=DELETE REPOSITORY SUPABASE_SERVICE_ROLE_KEY'

gh workflow run shared-secret-environment-migration.yml --repo $repo --ref main `
  -f mode=post-delete-audit `
  -f 'confirmation=AUDIT DELETED REPOSITORY SECRETS'
```

Each deletion job checks the required target Environment secret metadata,
requires every credential canary to succeed in the same run, deletes only the
selected repository secret, and immediately verifies its absence. A failed
validation prevents the deletion job from starting.

The internal-PR absence proof has two parts:

1. The Actions repository secret API no longer lists either name. With no
   repository-level value, a workflow added or modified on an internal branch
   cannot resolve it.
2. Open a short-lived internal canary PR whose job compares each secret
   expression to the empty string without printing either value. The job must
   pass, and the canary branch must never be merged. Record its run URL and close
   the PR after review.

Never run the canary while a repository copy exists: an internal PR is precisely
the trust boundary being removed.

## Rollback and rotation

If a group fails before repository-secret deletion, stop dispatching that group,
restore the last working workflow commit, and leave the repository fallback in
place. Do not weaken the environment branch policy.

If a group fails after deletion, restore only the affected environment secret
from the approved credential source or rotate the scoped provider credential.
Do not recreate a repository-level secret. Re-run the failed consumer and its
denied-access test before resuming other groups.

For rotation:

1. Issue a new provider credential with the same or narrower scope.
2. Update one environment secret.
3. Validate all consumers assigned to that environment.
4. Revoke the old credential at the provider.
5. Confirm a new run succeeds and the revoked credential fails.
6. Record provider credential ID, environments, run URLs, rotation date, and
   next review date without recording the secret value.
