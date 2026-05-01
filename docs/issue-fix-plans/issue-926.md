# Issue Fix Plan #926

- Issue: [[追加要望] 12インスタンス並行開発のリアルタイム競合予測を追加する](https://github.com/kanta13jp1/my_web_app/issues/926)
- Labels: `enhancement`, `priority:high`, `automation`, `追加要望`
- Workflow: `.github/workflows/github-issue-fix.yml`
- Repair PR: https://github.com/kanta13jp1/my_web_app/pull/994
- Source memo: NotebookLM `Codex vs Claude Code: The Ultimate AI Development Synergy` (`bc58b50b-5fc4-4840-9a62-b397d6d3b65a`)

## Goal

Add a lightweight conflict predictor that the 12-instance fleet can run before
session start, handoff, `git add`, and Supabase migration creation.

## Implementation

- Replace `scripts/instance_conflict_predictor.py` with a dependency-free Python
  guardrail.
- Detect recent file overlaps, open PR overlaps, dirty worktree overlaps, and
  migration timestamp collisions/clusters.
- Emit human-readable Markdown plus machine-readable JSON.
- Add configurable notification routes for console, Slack, Notion, and WBS.
- Add a GitHub Actions workflow that runs the predictor on relevant PRs and
  manual dispatch.
- Document the fleet operating procedure in
  `docs/INSTANCE_CONFLICT_PREDICTOR.md`.

## Acceptance Mapping

- `.claude` hook or existing script has a conflict prediction step:
  `scripts/instance_conflict_predictor.py`.
- Risk, files, related PR/commit/worktree, and recommended action are rendered
  in Markdown/JSON.
- Migration timestamp collisions are detected and the next free timestamp is
  suggested.
- Slack/Notion/WBS enablement is configurable through `--notify`; Notion/WBS use
  `--json-out` as the schema-safe handoff payload.

## Validation

- `python -m py_compile scripts/instance_conflict_predictor.py`
- `python scripts/instance_conflict_predictor.py --help`
- `python scripts/instance_conflict_predictor.py --files scripts/instance_conflict_predictor.py --notify console --json-out tmp/instance-conflict.json --output tmp/instance-conflict.md`
- `python scripts/instance_conflict_predictor.py --migration-timestamp 20260429070000 --notify console --json-out tmp/migration-risk.json --output tmp/migration-risk.md`

## Remaining Risk

The first version writes directly only to console/Slack. Notion and WBS writes
are deliberately left as JSON handoffs so the table-specific writers can own
schema changes safely.
