# Persistent production deployment hold

PR #5610 must not enter production until a separate explicit owner release approval.
Repository Actions variable `PRODUCTION_DEPLOY_HOLD=true` holds production.
Missing, invalid, or any value other than the exact lowercase `false` also holds it.
The hold is global: later main pushes and manual deploy-prod dispatches remain held.
deploy-prod CI/deploy/notification jobs and the dedicated core-hub deploy are guarded
before their production environment/secrets are entered. Read-only contract CI remains enabled.
This does not cancel a running release, roll back a release, or revoke credentials.
It does not authorize other publishers or alter dev/staging.

Before merging #5610, verify the remote variable is true, PR checks pass, and the
merged workflows retain all guards. Afterwards inspect the push run: production jobs
must be skipped and the hold summary emitted. Do not interpret skipped as deployed.

Only after separate explicit human approval: inspect queued/running releases, review
the entire main commit intended for production and all accumulated changes, then set
the variable to `false` and verify its read-back. Removing the variable is NOT release.
Do not clear it automatically, by TTL, or as part of this task. A later dispatch may
deploy the full main tree, not only #5610. Paid APIs and closing #5102 remain excluded.
