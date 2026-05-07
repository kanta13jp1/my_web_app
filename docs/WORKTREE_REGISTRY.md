# Worktree Registry

Issue: [#1574](https://github.com/kanta13jp1/my_web_app/issues/1574)

This is the local ownership layer for the current two-instance development
flow: Claude Code #1 (Windows app) and Codex #1 (Windows app). It records which
instance owns a task, which worktree/branch it is using, and which paths it
plans to edit before work starts.

The registry file is local by default:

```powershell
.cache\worktree-registry.json
```

`.cache/` is gitignored, so machine-specific paths and in-progress ownership do
not leak into commits. The committed script is the shared contract; each
session writes its own local registry.

## Session Start

Create a fresh task worktree from latest `origin/main`, then register the
planned write scope before editing:

```powershell
python scripts\worktree_registry.py register `
  --instance codex1 `
  --owner "Codex #1 (Windows app)" `
  --issue 1574 `
  --paths scripts/worktree_registry.py docs/WORKTREE_REGISTRY.md
```

Run preflight with the same path scope:

```powershell
python scripts\worktree_registry.py preflight `
  --instance codex1 `
  --issue 1574 `
  --paths scripts/worktree_registry.py docs/WORKTREE_REGISTRY.md `
  --output tmp/worktree-registry-preflight.md `
  --json-out tmp/worktree-registry-preflight.json `
  --fail-on high
```

Before staging, use the staged-file mode:

```powershell
python scripts\worktree_registry.py preflight `
  --instance codex1 `
  --issue 1574 `
  --staged `
  --fail-on high
```

Release the reservation after the PR is merged and the worktree is removed:

```powershell
python scripts\worktree_registry.py release --instance codex1 --issue 1574
```

## What It Checks

- Primary worktree dirty state, including overlap with planned paths.
- Dirty sibling worktrees that already edit the same planned files.
- Registry reservations from another instance or issue.
- Current branch behind upstream.
- Current branch ahead of upstream without a detected PR.

`High` means stop and coordinate before editing or staging. `Medium` means keep
the fresh worktree isolation, rebase if needed, and avoid root dirty files.

## Listing Ownership

```powershell
python scripts\worktree_registry.py list
python scripts\worktree_registry.py list --json
```

The listing includes both registered active entries and live `git worktree`
entries. That gives a compact view of active workdirs even when old dormant
worktrees remain for historical recovery.

## Relationship To Existing Guards

`scripts/instance_conflict_predictor.py` remains the broader predictor for
recent commits, open PRs, dirty worktrees, and migration timestamps. The
registry is the earlier gate:

1. Register planned ownership.
2. Run registry preflight before editing and before staging.
3. Run `instance_conflict_predictor.py` for PR-level overlap and migration
   guidance.
4. Merge only after CI is green, then remove the task worktree and release the
   registry entry.

This keeps user changes in the primary worktree protected while still allowing
Claude Code #1 and Codex #1 to move in parallel without reviving the old
12-instance memory footprint.
