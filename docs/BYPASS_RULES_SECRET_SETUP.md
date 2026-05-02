# BYPASS_RULES Secret Setup

Role: Codex / Claude quota fallback

`BYPASS_RULES` is a GitHub Actions repository secret used by selected automation
workflows when they need write-capable checkout or push credentials. The secret
value cannot be read back from GitHub, so normal verification checks only that
the secret exists and that a workflow using it can complete without `GH006`.

## Verify The Secret Exists

Run this from the repository root:

```powershell
.\scripts\set_bypass_rules_secret.ps1 -Repo "kanta13jp1/my_web_app" -VerifyOnly
```

Expected result:

```text
OK: BYPASS_RULES exists in kanta13jp1/my_web_app
```

Codex #1 verified this on 2026-05-02 with `gh secret list`, which showed
`BYPASS_RULES` configured.

## Smoke Test

Use a workflow that checks out with `secrets.BYPASS_RULES || github.token` and
can safely run manually:

```powershell
gh workflow run ai-tool-watch.yml --repo kanta13jp1/my_web_app -f comment_mode=never
gh run list --repo kanta13jp1/my_web_app --workflow "AI Tool Changelog Watch" --limit 3
```

Codex #1 smoke-tested this on 2026-05-02:

- Workflow: `AI Tool Changelog Watch`
- Run: `25249810490`
- Result: success
- `GH006` protected-branch errors: none observed

## Rotate The Secret

Only rotate the token if workflows start failing with permission errors, expired
credentials, or `GH006`.

```powershell
.\scripts\set_bypass_rules_secret.ps1 -Repo "kanta13jp1/my_web_app"
```

Recommended token permissions:

- Repository: `kanta13jp1/my_web_app`
- Contents: read and write
- Workflows: read and write, when workflow file changes are required
- Branch protection bypass: only when the workflow genuinely needs protected
  branch writes

The script prompts for the value as a `SecureString`, writes it to a temporary
file for `gh secret set --body-file`, and deletes the temporary file afterward.
Do not pass secret values directly on the command line.

## Workflows That Reference BYPASS_RULES

Examples include:

- `.github/workflows/ai-tool-watch.yml`
- `.github/workflows/ai-tool-changelog-watch.yml`
- `.github/workflows/ai-university-update.yml`
- `.github/workflows/blog-publish.yml`
- `.github/workflows/blog-draft.yml`
- `.github/workflows/blog-verify.yml`
- `.github/workflows/daily-report.yml`

## Notes

- Never paste the secret value into docs, migrations, issues, or chat.
- Treat GitHub as the source of truth for whether the secret exists.
- Treat a successful workflow smoke test as the practical proof that current
  automation can use the credential path.
