# Remote signed-commit path (Issue #1286)

Preparation only: this does not authorize branch-rule changes or history rewriting.
Issue #1284 still requires an independent reviewer.

## Platform contract

GitHub GraphQL createCommitOnBranch appends a commit and atomically checks
expectedHeadOid. GitHub documents server-side signing when supported. The author
is the authenticated credential owner, not an independently approving reviewer.

- https://docs.github.com/en/graphql/reference/commits#createcommitonbranch
- https://github.blog/changelog/2021-09-13-a-simpler-api-for-authoring-commits/

## Bounded procedure

1. Resolve remote main and create a scoped codex/ branch, never edit main.
2. Review exact files, excluding secrets, private data and unrelated edits.
3. Use createCommitOnBranch with branch.repositoryNameWithOwner,
   branch.branchName, expectedHeadOid, message and fileChanges.additions.
   Encode UTF-8 file contents as base64. The live API requires branchName;
   prose documentation may refer to refName. Validate the actual input schema.
4. Inspect GraphQL errors even when HTTP succeeds. A head mismatch requires
   fresh inspection, never a force update or blind retry.
5. Verify the branch points to the returned SHA. Read REST commits/{sha} and
   require commit.verification.verified=true and reason=valid before claiming
   a verified signature.
6. Open a Draft PR and validate the exact revision with GitHub Actions.
   Record the proof SHA, verification and CI results in the PR and Issue.
7. On an uncertain response, reconcile branch/commit state before any retry.
   Never silently fall back to unsigned commits when signatures are required.

No private signing key needs to be generated or uploaded for this route.
Use existing host-managed authentication, never print the token.

## Limits

A signed documentation commit proves this credential/file-type path only.
It does not retroactively sign existing commits, prove all bot/token types,
or establish unsigned-PR rejection. File modes, symlinks, large/binary payloads
and merge methods need separate compatibility checks. Preserve existing history.

Review all publishers, choose independent reviewers and rollback ownership, and
obtain explicit human review before enabling admin/signature/linear-history
enforcement. Signing is provenance, not proof of code correctness or human review.
