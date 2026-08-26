# Container Resource Cleanup

Issue: [#2843](https://github.com/kanta13jp1/my_web_app/issues/2843)

Use this runbook monthly, when `docker system df` reports meaningful reclaimable
space, or before container storage causes the development drive to cross its
capacity threshold. The repository-owned path is deliberately conservative:
automated cleanup never deletes a Docker volume.

## Safe default

In VS Code, open **Terminal > Run Task** and run:

1. `Containers: audit cleanup safety`
2. Review Docker disk usage and every volume whose name or label is marked as a
   protected Supabase/Postgres candidate.
3. Run `Containers: safe prune (volumes excluded)` only if the listed stopped
   containers, dangling images, networks, and build cache are no longer needed.
4. Enter `PRUNE_WITHOUT_VOLUMES` when prompted.

The apply task runs this bounded command:

```text
docker system prune --force --filter until=168h
```

It never appends `--volumes`, never runs `docker volume prune`, and never runs
`supabase stop --no-backup`. The default script invocation is read-only:

```powershell
python scripts/container_cleanup_guard.py
python scripts/container_cleanup_guard.py --json
```

## VS Code command-palette cleanup

The Microsoft Container Tools extension currently exposes **Containers: Prune
System**. Its implementation warns that stopped containers, dangling images,
unused networks, and unused volumes will be removed. Because unused Supabase
database volumes may be valuable, do not use that command as the routine path
for this repository. Use the volume-excluding task above.

If **Dev Containers: Clean Up Dev Containers...** is available in the installed
Dev Containers extension, review every proposed container first. That command
does not replace the database backup and volume inventory steps below. Extension
command names can vary by release, so search the command palette for `Clean Up`
instead of assuming the older display name is present.

## Protect local Supabase data before any manual volume removal

The safe task does not remove volumes. Before a separate, intentional reset or
manual removal of one exact volume:

1. Keep the local Supabase stack running while creating the dump.
2. Store the dump outside Docker-managed storage and outside the Git worktree.
3. Create role, schema, and data dumps and verify that all three files are
   non-empty.

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$documents = [Environment]::GetFolderPath('MyDocuments')
$backupRoot = Join-Path $documents "my_web_app-local-backups\$stamp"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

supabase db dump --local --role-only --file (Join-Path $backupRoot 'roles.sql')
supabase db dump --local --file (Join-Path $backupRoot 'schema.sql')
supabase db dump --local --data-only --use-copy --file (Join-Path $backupRoot 'data.sql')

Get-ChildItem -LiteralPath $backupRoot |
  Select-Object Name, Length, @{Name='SHA256';Expression={(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}
```

Stop the project with `supabase stop` only after verifying the backup. Supabase
documents that normal `supabase stop` preserves Docker resources across
restarts, while `--no-backup` deletes local data volumes. Never use
`supabase stop --all --no-backup` for routine maintenance.

Before deleting any exact volume manually, run the audit again, record the
volume name, backup directory, hashes, and why the volume is obsolete in the
Issue or maintenance log. Do not use a wildcard, a name inferred from a partial
match, or a machine-wide volume prune.

## Recovery check

After cleanup:

1. Start the local stack with `supabase start`.
2. Run `supabase status` and confirm the expected local URLs.
3. Open the Flutter Web app against the local environment and verify one read
   and one reversible write through the relevant feature.
4. If local data is missing, stop work and restore from the recorded dump before
   making further changes.

## Primary references

- [Microsoft Container Tools source: system prune removes unused volumes](https://github.com/microsoft/vscode-containers/blob/main/extensions/vscode-containers/src/commands/pruneSystem.ts)
- [Microsoft Container Tools command overview](https://github.com/microsoft/vscode-containers/blob/main/extensions/vscode-containers/README.md)
- [Docker pruning documentation](https://docs.docker.com/engine/manage-resources/pruning/)
- [Supabase CLI `stop` reference](https://supabase.com/docs/reference/cli/supabase-stop)
- [Supabase CLI `db dump` reference](https://supabase.com/docs/reference/cli/supabase-db-dump)
