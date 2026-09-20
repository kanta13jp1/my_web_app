---
title: "Agent skill curation completion"
type: decision
date: 2026-09-21
status: implemented-pending-review
tags: [skills, codex, ci]
---

# Agent skill curation completion

The canonical adoption decisions remain in [the curation ADR](../../docs/adr/2026-08-15-agent-skill-curation.md): 14 accepted candidates plus the existing asset-management skill; the 15 retired candidates are absent from the canonical branch. Wiki command examples follow current CLI help, and design criteria belong to `docs/DESIGN.md`.

The interrupted follow-up was completed in `C:/Users/kanta/GitHub/my_web_app_skill_curate`, on `codex/rescue-skill-curation-20260815`. The dirty primary checkout was left unchanged. August 23 rescue commit `6f7a0d8b6` already contained the remote-delete safeguards and eleven UTF-8 metadata conversions; those changes were preserved, not recreated.

- Rebased the five preserved commits onto `origin/main` at `1d8e5a8c8c9c4c84d403164e95bc39293d7817cd`. Original history is retained on local branch `codex/skill-curation-pre-integration-20260921`.
- Added offline MUSUBI and YouTube behavioral tests; made YouTube paths derive from the selected checkout and user profile; made CLI help independent of Google API dependencies.
- Retained seven newer upstream skills in the A/B manifest (22 total: A 11, B 11) and preserved the upstream accessibility-audit requirement while resolving design SSOT conflicts.
- Validation: 32 lightweight Python tests pass; all 22 metadata/frontmatter contracts, 17 relative links, and 27 CLI smoke commands pass; `git diff --check` passes. No OAuth, uploads, media rendering, Flutter/Dart, or production actions ran.
- Cloud-first routing was mandatory (2.08 GiB free disk, 90% memory). The draft PR and its Agent Skill Contract check are the review/cloud-validation handoff; main is not merged. Local Git hooks reported missing `lefthook`, so only the explicitly reported checks are claimed.

Implementation was completed by one bounded routed Codex worker, with no additional child workers or worktrees. Its validation impact is the offline contract coverage; cleanup impact is limited to temporary test directories automatically removed by the tests. No user files, branches, or tabs were deleted.

Review artifact: [draft PR #5449](https://github.com/kanta13jp1/my_web_app/pull/5449). Implementation commit: `42f9c19c4d2e2e31e300166720e7045025f18d57`. The [Agent Skill Contract cloud run](https://github.com/kanta13jp1/my_web_app/actions/runs/35532151457) passed all unit, documentation, metadata, link, and smoke steps for that commit on Ubuntu/Python 3.12. Standard repository CI remains separately visible on the PR. Main advanced after the integration snapshot; another update may be needed before an eventual owner-approved merge.
