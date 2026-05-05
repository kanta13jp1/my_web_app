# Blog Publish Status Automation

Issue: #1304

Published draft status updates no longer push directly to `main`. The
`blog-publish.yml` workflow now delegates the frontmatter update to
`scripts/blog_mark_published_status.sh`, which is safe under branch protection.

## Flow

1. After a successful publish, mark the selected draft and optional English
   draft as `published: true`.
2. Commit the change to `blog-publish/<run_id>-<timestamp>`.
3. Push that branch with `BLOG_PAT` when configured. Fallback token order is:
   `BLOG_PAT`, `GH_PAT_BLOG_MERGE`, `BYPASS_RULES`, then `GITHUB_TOKEN`.
4. Create a PR to `main`.
5. If the token can bypass/merge under branch protection, squash merge the PR
   and delete the branch automatically.
6. If PR creation or merge is unavailable, leave the branch/PR for manual
   merge instead of retrying a protected direct push.

## Required Secret

Prefer `BLOG_PAT` as the dedicated publish-status token. It should have the
least privilege that can push workflow-created branches, create pull requests,
and merge the status PR according to the repository branch protection rules.

## Local Checks

```bash
bash -n scripts/blog_mark_published_status.sh
```
