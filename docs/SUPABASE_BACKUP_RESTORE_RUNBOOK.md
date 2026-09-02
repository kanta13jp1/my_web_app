# Supabase database backup / restore runbook

- Owner: CEO（Supabase Organization Owner）
- Automation: `.github/workflows/supabase-backup-restore.yml`
- Source project: `my-web-app` (`smmkxxavexumewbfaqpy`)
- Related Issue: [#1291](https://github.com/kanta13jp1/my_web_app/issues/1291)
- Last reviewed: 2026-08-26 JST

## 1. Service objective

| Item | Current target |
| --- | --- |
| Backup frequency | Weekly, Monday 02:23 JST; additionally before any planned project deletion/transfer or high-risk data operation |
| Off-site retention | GitHub Actions encrypted artifact, 35 days（最大5世代） |
| Restore drill | Every backup run restores into an ephemeral local Supabase/PostgreSQL target |
| RPO | At most 7 days under the regular schedule; manual pre-change backup reduces planned-change RPO |
| Drill RTO target | 60 minutes（workflow timeout） |
| Production recovery RTO | Not guaranteed on Free plan; target 4 hours after a replacement Supabase project is available |
| Failure handling | `schedule-resilience-watch.yml` retries once and creates/updates a `workflow-failure` Issue |

The current project is on Free plan as confirmed by the custom-domain entitlement check for
Issue #1290. Supabase recommends regular off-site logical exports for Free projects. If the
organization upgrades to Pro, daily platform backups become available with a seven-day window;
this independent logical export must still be kept because deleting a project permanently removes
the platform-held backups too.

## 2. What is protected

Each run follows Supabase's official CLI backup sequence and creates:

1. `roles.sql` — database roles (`--role-only`)
2. `schema.sql` — application-owned database schema
3. `data.sql` — logical data export (`--data-only --use-copy`)
4. `manifest.json` — byte sizes and SHA-256 digests of the three files

The four files are packed into a header-encrypted AES-256 7z archive. Only that archive and a
sanitized restore-evidence JSON are uploaded. Plain SQL is deleted from the runner before upload.
The repository is public, so uploading plaintext dumps is prohibited even if an artifact is
expected to require authentication.

### Explicit exclusions

- Storage binary objects are not contained in database backups. The database only contains Storage
  metadata. A separate Storage object export is required before the product stores irreplaceable
  customer files.
- Edge Function source is recovered from Git; function secrets are recovered from the approved
  secret manager / GitHub Actions Secrets.
- Auth dashboard settings, API keys, Realtime settings, non-default extension settings, and
  read replicas must be recreated from the environment inventory.
- `storage.buckets_vectors` and `storage.vector_indexes` are excluded per the official Supabase CLI
  migration procedure.

## 3. Encryption key

Repository secret `SUPABASE_BACKUP_PASSPHRASE` is required and must contain at least 32 random
characters.

- The value must never appear in source, Issue/PR text, artifacts, workflow logs, or chat.
- Only workflows committed to protected `main` may consume it.
- The CEO must also retain the value in the approved password manager. GitHub does not allow reading
  a repository secret back after creation.
- Rotate it only after every artifact encrypted with the previous value has expired or has been
  re-encrypted. Record the rotation date without recording the value.
- If exposure is suspected, stop scheduled backups, rotate the key, delete affected artifacts, and
  follow `ONCALL_INCIDENT_SOP.md`.

## 4. Automated backup and restore drill

The workflow may run only on `refs/heads/main` and has read-only repository permissions.

1. Validate `SUPABASE_ACCESS_TOKEN`, production project ref/password, and backup passphrase.
2. Link to production and run three read-only logical dumps.
3. Create the digest manifest.
4. Encrypt the bundle with encrypted headers, verify it is non-empty, and delete plaintext.
5. Decrypt into a new runner directory and verify every digest and byte size.
6. Start a fresh local Supabase Postgres 17 target with no repository migrations.
7. Connect over container-local loopback TCP as the local `supabase_storage_admin` table owner,
   using the database password already injected into the ephemeral container, and apply the
   checksum-verified Storage compatibility migration in its own fail-closed transaction. Reconnect
   as `postgres` for the exported roles, schema, and data restore.
8. Recreate non-partitioned, logged PGMQ queue relations found as matching `pgmq.q_*` / `pgmq.a_*` COPY
   pairs. The CLI intentionally omits extension-managed DDL, so these relations must exist before
   queue rows can be restored. Remove the bootstrap metadata rows only when source PGMQ metadata is
   present, allowing the source metadata to be restored without a duplicate key.
9. Restore roles, schema, and data in a single transaction with `ON_ERROR_STOP=1`.
10. Advance each restored PGMQ queue sequence to its maximum restored message ID.
11. Parse every `COPY` block for the `public` and `pgmq` schemas and assert the restored row count
    of every table.
12. Stop/delete the ephemeral restore target and remove decrypted SQL.
13. Upload only the encrypted bundle and sanitized evidence for 35 days.

This proves that the exact encrypted artifact can be decrypted and that application-owned database
tables plus durable PGMQ messages can be restored outside the source project. It never writes to
production or staging. Queue bootstrap is derived only from quoted COPY relation identifiers; the
generator rejects an archive/active table mismatch and quotes every generated SQL identifier and
literal. The current project queue uses `pgmq.create(...)`; the drill fails closed if restored
metadata identifies a partitioned or unlogged queue, which requires a mode-aware bootstrap before
it can be accepted as recoverable.

## 5. Manual operation

### Run a backup before a high-risk change

```powershell
gh workflow run supabase-backup-restore.yml `
  --repo kanta13jp1/my_web_app `
  --ref main

gh run list `
  --repo kanta13jp1/my_web_app `
  --workflow supabase-backup-restore.yml `
  --limit 1
```

Do not continue with a planned project deletion/transfer until the run is `success`, its evidence
says `result: passed`, and the encrypted artifact is present.

### Download a retained bundle

```powershell
gh run download <run-id> `
  --repo kanta13jp1/my_web_app `
  --name supabase-production-backup-<run-id>-<attempt> `
  --dir C:\approved-encrypted-backup-location
```

Keep it encrypted. Decrypt only on a BitLocker/device-encrypted trusted machine or inside a trusted
recovery runner, and delete plaintext immediately after the restore.

## 6. Full recovery into another Supabase project

This is a disaster procedure, not the weekly drill. It creates/writes a replacement project and
requires an explicit CEO recovery decision recorded in an Incident Issue.

1. Declare an incident and record the last-known-good backup run/artifact SHA-256.
2. Create the replacement Supabase project in the approved organization/region.
3. Inventory/enable required extensions and Database Webhooks.
4. Download and decrypt the selected archive on a trusted recovery runner.
5. Obtain the replacement project's Session Pooler connection string and password.
6. Restore using the official sequence:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$NEW_DB_URL"
```

7. Apply separately maintained Auth/Storage schema changes from migrations/diff if required.
8. Deploy Edge Functions and set secrets without logging their values.
9. Migrate Storage objects from the independent object backup when applicable.
10. Recreate Auth URLs/providers, Realtime publications, extension settings, and scheduled jobs.
11. Compare table counts and run authentication, RLS, Edge Function, Storage, and application smoke.
12. Change `SUPABASE_URL_PROD`, anon key, and deploy only after recovery validation succeeds.
13. Keep the source/replacement projects isolated until the CEO signs off on cutover.
14. Securely delete decrypted files and attach only sanitized evidence to the Incident Issue.

Never test this path by overwriting staging or production. A real replacement-project drill requires
a separately approved disposable project and its own deletion approval after evidence review.

## 7. Delete project / Transfer project access rule

Supabase Organization Owner is the only role permitted to authorize these operations. Because the
current organization has one human operator, a second-person approval cannot be claimed; the
following logged compensating controls are mandatory.

### Common controls

- Organization Owner access belongs only to the human CEO with MFA. AI agents, CI tokens, and routine
  automation must not receive Owner authority for project deletion/transfer.
- The exact organization ID, project ref, source/destination, reason, owner, and scheduled time must
  be written in an Issue before the action.
- The latest successful backup/restore run must be less than 24 hours old and linked in the Issue.
- The Owner must re-read the target project ref from the dashboard and compare it with the Issue.
- Never perform the action from a mobile browser, an untrusted network, or during an active incident
  unless it is part of the approved recovery plan.
- Quarterly access review records the current Organization Owners and removes unnecessary Owner roles.

### Delete project

- Default rule: production deletion is prohibited.
- Planned deletion requires an explicit `DELETE <project-ref>` approval in the Issue after a 24-hour
  cooling-off period and after the off-site encrypted artifact has been downloaded/verified.
- The Issue must state that database backups held by Supabase and Storage objects are also permanently
  deleted. The deletion itself is never delegated to an AI agent or automated workflow.

### Transfer project

- Record and verify the destination organization ID, billing owner, region/plan implications, and
  post-transfer administrator before transfer.
- Confirm required integrations/secrets and the rollback/escalation route before starting.
- Run Auth, database, Edge Function, Storage, and deployment smoke after transfer. Do not remove the
  old organization's access record until verification completes.

## 8. Review cadence

| Cadence | Review |
| --- | --- |
| Weekly | Latest scheduled run succeeded, encrypted artifact exists, restore evidence passed |
| Monthly | Old artifacts expire as intended; workflow/CLI version and storage exclusions remain current |
| Quarterly | Supabase Organization Owner list, GitHub secret access, restore runbook tabletop review |
| Before deletion/transfer | Fresh backup + restore drill within 24 hours and explicit Owner approval |
| After schema/Auth/Storage changes | Confirm the logical dump and restore scope still covers the change |

The workflow pins Supabase CLI 2.115.0 because its local Auth schema matches the production
`auth.custom_oauth_providers.custom_claims_allowlist` column observed during the first drill.
Production Storage moved to v1.71.0 after that CLI release. Before applying the dump, the workflow
therefore verifies and applies the exact upstream additive migration
`scripts/sql/supabase_storage_v1_71_0_0062.sql` (SHA-256
`45969060b55102f56af317b0d7981434be58927de1ff76e1e1789139a3f2defc`) to the ephemeral target.
It is vendored byte-for-byte from Supabase Storage tag `v1.71.0`, commit
`e05eb148dce70c55d7b4d9b524a3b20835b1e165`; it never runs against production or staging.
The local Supabase image owns the affected tables as the login-enabled
`supabase_storage_admin` role. The workflow connects as that existing owner only for this migration,
then opens a separate `postgres` transaction for the exported roles, schema, and data. The owner
connection uses the ephemeral container's existing `POSTGRES_PASSWORD` over loopback TCP without
printing or copying the value into repository source. It does not depend on local socket peer
authentication or on `postgres` being allowed to use `SET ROLE`, both of which vary across images.

Upgrade the CLI pin deliberately when its local Storage schema includes migration 0062, then remove
the compatibility file and checksum in the same PR. A restore failure caused by a missing managed
column is a compatibility failure and must not be waived.

## 9. Official references

- [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups)
- [Backup and Restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
- [Restore dashboard backup](https://supabase.com/docs/guides/platform/migrating-within-supabase/dashboard-restore)
- [Supabase Storage v1.71.0 migration 0062](https://github.com/supabase/storage/blob/v1.71.0/migrations/tenant/0062-object-versioning-core.sql)
- [Transfer projects](https://supabase.com/docs/guides/platform/project-transfer)
