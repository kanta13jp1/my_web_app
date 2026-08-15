# Agent Skill Curation From origin/main

- Status: Accepted
- Date: 2026-08-15
- Scope: 29 untracked project-local skill candidates found in `C:\Users\kanta\GitHub\my_web_app\.agents\skills`
- Canonical base: `origin/main` at worktree creation

## Context

The source worktree was on `codex/issue-1215-hitl`, thousands of commits behind `origin/main`, with 276 dirty paths. Its entire `.agents/skills` directory was untracked. The runtime could discover 27 of 29 local candidates, but Git did not preserve them on that branch.

The curation therefore uses a clean `codex/skill-curation-20260815` worktree created from current `origin/main`. The dirty source worktree remains untouched. A candidate marked **retire** is omitted from the canonical worktree; this decision does not delete the user's untracked source copy.

## Decision criteria

Adopt a skill only when it:

1. provides repository-specific reusable knowledge or deterministic tooling;
2. has valid `name` and `description` frontmatter;
3. matches current CLI commands, paths, schema, and the two-instance operating model;
4. preserves dirty worktrees and separates read-only checks from mutations;
5. requires review or explicit approval before destructive, public, production, or home-directory changes;
6. avoids duplicating a stronger installed skill or another canonical project skill;
7. has testable validation and does not push directly to `main`.

## Candidate decisions

| Candidate | Decision | Canonical action | Reason |
| --- | --- | --- | --- |
| `ai-university-add-provider` | Adopt after rewrite | Add | Keep discovery/add workflow; remove hard-coded provider inventory, stale schema assumptions, and direct-main push. |
| `blog-publish-cleanup` | Retire | Omit | Remote branch merge/deletion belongs in a deterministic workflow with SHA and PR proof, not an auto-triggered skill. |
| `cross-instance-pr` | Adopt after rewrite | Add | Preserve durable handoffs but limit top-level owners to Claude Code #1 and Codex #1. |
| `github-backlog-worktree-drain` | Adopt | Add package | Strong checkpoint, SHA proof, cleanup checker, and passing bundled tests. |
| `github-reuse-first` | Retire | Omit | A newer global skill with the same name already supports GitHub app, `gh`, official API, and Web fallback; a project copy would duplicate and shadow it. |
| `hook-rule-audit` | Adopt after rewrite | Add | Keep read-only audit; replace legacy instance counts and private-memory heuristics with canonical rule verification. |
| `mobile-bug-triage` | Retire | Omit | Mobile is a dormant top-level lane and the skill depends on obsolete GitHub MCP names. |
| `musubi-social-release-pipeline` | Adopt | Add package | Strong staging, RLS, JWT, release, and resource-pressure gates. |
| `nano-banana` | Retire | Omit | Missing frontmatter, stale/inconsistent model instructions, and duplicates the installed image-generation capability. |
| `qiita-retry` | Retire | Omit | Conflicts with another cooldown policy and mixes rate-limit checks with unsafe branch mutation. |
| `rule17-wf-health` | Retire | Omit | A health audit must not mass-delete remote branches or push directly to main. |
| `session-start-check` | Adopt after rewrite | Add | Keep the required repository intake while removing old worktree layout, fleet assumptions, WBS writes, and broken links. |
| `source-command-design-review` | Retire and integrate | Omit | Move the reusable review workflow into `docs/DESIGN.md`; discard conflicting note-theme values and keep one SSOT. |
| `source-command-wiki-broken-cleanup` | Retire | Omit | Redundant wrapper with stale paths and invalid CLI flags. |
| `source-command-wiki-compile` | Retire | Omit | Redundant wrapper and omitted the required `--apply` write flag. |
| `source-command-wiki-dup-h1-cleanup` | Retire | Omit | Redundant wrapper with stale paths and validation commands. |
| `source-command-wiki-lint` | Retire | Omit | Redundant wrapper calling the removed `--report` option. |
| `source-command-wiki-orphan-batch` | Retire | Omit | Redundant wrapper with stale paths and validation commands. |
| `source-command-wrap-up` | Retire | Omit | Bloated legacy fleet/WBS/home-memory routine with hidden external writes. |
| `t1-blog-dispatch` | Retire | Omit | Conflicting Qiita policy, run-selection races, and unsafe branch mutation. |
| `ui-design` | Retire and integrate | Omit | Move responsive, accessibility, and validation guidance into `docs/DESIGN.md`; discard the conflicting light-theme token copy. |
| `wiki-broken-cleanup` | Adopt after rewrite | Add | Keep the deterministic cleanup script; require fresh lint, dry run, semantic review, and scoped backup handling. |
| `wiki-compile` | Adopt after rewrite | Add | Keep managed compilation and document that the default is dry-run and `--apply` performs writes. |
| `wiki-dup-h1-cleanup` | Adopt after rewrite | Add | Keep deterministic detection with semantic review and no broad backup deletion. |
| `wiki-ingest` | Adopt after rewrite | Add | Preserve draft/save workflow and require explicit approval before durable storage. |
| `wiki-lint` | Adopt after rewrite | Add | Replace removed `--report` with the current CLI and keep audit read-only by default. |
| `wiki-orphan-batch` | Adopt after rewrite | Add | Keep bounded indexing with dry-run and semantic review; reject opaque 250-item mutations. |
| `wiki-query` | Adopt after rewrite | Add | Replace removed `notebooklm query` with `notebooklm ask` and add a local-search fallback. |
| `youtube-video-pipeline` | Retain canonical | Keep `origin/main` package | Existing canonical package has explicit copyright, consent, private-upload, publication, and production gates. Reject the untracked divergent copy as a source of truth. |

## Existing canonical skill outside the 29 candidates

Retain `asset-management-wbs-release`. Replace its dependency on the retired `source-command-wrap-up` with the current `AGENTS.md` wrap-up and WBS policy.

## A/B CI grades

- **A**: retained or adopted without a core workflow rewrite: `asset-management-wbs-release`, `github-backlog-worktree-drain`, `musubi-social-release-pipeline`, and `youtube-video-pipeline`.
- **B**: adopted after rewriting stale commands, paths, operating-model assumptions, or safety gates: the other eleven canonical skills.

`.agents/skills/ci-manifest.json` is the executable classification. Every active canonical skill must appear exactly once as A or B and declare at least one allowlisted CLI smoke. `.github/workflows/agent-skill-contract.yml` runs the shared frontmatter lint, relative Markdown-link check, and CLI smoke test for skill or referenced-CLI changes.

## Result

The canonical set contains 15 skills:

- 14 accepted candidates, including the retained YouTube package;
- `asset-management-wbs-release`, which already existed on `origin/main`.

The five wiki slash-command wrappers and ten other unsafe, duplicated, or superseded candidates remain absent. Future candidates must pass the skill-creator validator, relative-link checks, command smoke tests, and package-specific tests before adoption. `test/scripts/test_agent_skill_cli_contract.py` locks the active Wiki examples to the local script help contract and rejects the retired lint and NotebookLM command forms.

The tracked `.claude/skills/ui-design/SKILL.md` and `.claude/commands/design-review.md` copies are also removed. Design entry points contain workflow only and defer all tokens and review criteria to `docs/DESIGN.md`.
