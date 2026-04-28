---
title: "GitHub Actions Security: Secrets, OIDC, and Least Privilege in Practice"
tags: ai,indiedev,automation,programming
published: true
---

# GitHub Actions Security: Secrets, OIDC, and Least Privilege in Practice

Running GHA in production reveals security traps fast. Here are the mistakes I made and how I fixed them.

## Common Dangerous Patterns

```yaml
# ❌ BAD: logging secrets
- run: echo "Token is ${{ secrets.API_TOKEN }}"

# ❌ BAD: pull_request_target runs fork code with elevated permissions
on:
  pull_request_target:

# ❌ BAD: over-permissioned
permissions:
  contents: write
  packages: write
  # only reading is actually needed
```

## Safe Secrets Handling

```yaml
# ✅ GOOD: pass through env (won't appear in logs)
- name: Deploy
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
  run: ./deploy.sh  # references $API_TOKEN inside script
```

**Repository Secrets vs Environment Secrets**:

```
Repository Secrets:   accessible from any workflow (higher risk)
Environment Secrets:  scoped to specific environments (production only)
```

```yaml
jobs:
  deploy:
    environment: production  # only this job can access production secrets
    steps:
      - run: echo ${{ secrets.PROD_KEY }}
```

## OIDC: Eliminate Long-Lived Credentials

With OIDC, you don't need static AWS/GCP/Azure credentials at all:

```yaml
# ✅ AWS OIDC — no ACCESS_KEY_ID or SECRET_ACCESS_KEY needed
jobs:
  deploy:
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-role
          aws-region: ap-northeast-1
```

```json
// AWS IAM Trust Policy
{
  "Principal": {
    "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
  },
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:sub":
        "repo:myorg/myrepo:environment:production"
    }
  }
}
```

## Least Privilege Permissions

```yaml
# ✅ Grant only what each job needs
jobs:
  test:
    permissions:
      contents: read

  deploy:
    permissions:
      contents: read
      id-token: write  # only added for OIDC
```

```yaml
# ✅ Default read-only at workflow level
permissions:
  contents: read

jobs:
  release:
    permissions:
      contents: write  # only this job gets write access
```

## Prevent Script Injection

```yaml
# ❌ BAD: embedding GitHub context directly in run
- run: echo "PR title: ${{ github.event.pull_request.title }}"
# if the PR title contains "; rm -rf /" — dangerous

# ✅ GOOD: pass through env (shell escapes it)
- env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR title: $PR_TITLE"
```

## Pin Actions to Commit Hashes

```yaml
# ❌ BAD: tags can be rewritten
- uses: actions/checkout@v4

# ✅ GOOD: commit hash is immutable
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

## Summary

```
Priority order:
  1. Pass secrets via env (prevent log exposure)
  2. Least privilege permissions (per-job)
  3. OIDC to eliminate static credentials
  4. Script injection: route github.event.* through env
  5. Pin actions to commit hashes
```

GHA security is full of traps you don't know about until you're already in them. One-time setup, lasting protection — high ROI for any project running automation in production.
