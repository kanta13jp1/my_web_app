# GitHub Actions Dispatch Guard

Last updated: 2026-05-05

Use `scripts/check_remote_synced.py` before manually dispatching workflows that read files from the repository, especially blog publishing and deploy helpers.

Default check:

```bash
python scripts/check_remote_synced.py --remote origin --branch main
```

Strict dispatch check:

```bash
python scripts/check_remote_synced.py --remote origin --branch main --require-clean
```

Behavior:

- Fetches `origin/main` before comparing refs.
- Blocks when `HEAD` contains commits that are not reachable from `origin/main`.
- With `--require-clean`, blocks meaningful uncommitted files as well.
- Ignores `.claude/settings.local.json` by default because it is local app state.

NPM wrappers:

```bash
npm run workflow:guard
npm run workflow:blog-publish -- <slug> [platforms]
```

