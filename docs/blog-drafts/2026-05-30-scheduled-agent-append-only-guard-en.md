---
title: "The Day a Scheduled AI Agent Erased 31,000 Lines — append-only discipline and verify-first detection"
tags: AI,ClaudeCode,automation,devops
published: true
---

Automated AI agents are convenient — until a task as simple as "update a file" turns into a destructive operation. This post uses a real **ROADMAP truncation incident** from our operations to explain the **append-only discipline** that keeps scheduled agents from destroying large shared files, and the **verify-first** pattern that caught the damage immediately.

## What happened

Our growth-strategy log, `GROWTH_STRATEGY_ROADMAP.md`, had grown to a single file of **31,323 lines**. Then, **52 seconds after** a PR was merged to main, a scheduled "roadmap update" agent fired an automated commit.

The commit looked like this:

```
1 insertion(+), 31,318 deletions(-)
```

The file was wiped down to a few header lines. The cause was simple: the agent wrote back an "updated" version with a **full Write (whole-file overwrite)** without reading the existing content first. Right after the merge its checkout hadn't caught up, so the agent treated near-empty content as the source of truth and overwrote everything.

## Why it was caught — verify-first

What saved us was an operating rule: **treat the prompt's premises as hypotheses and always cross-check them against date / KPI / git / PR / issue state**. At the start of the next session, the state check flagged "the ROADMAP is abnormally short" instantly, and it was handled as an incident.

Recovery itself was a one-liner thanks to git:

```bash
# Restore the file from the last-good commit
git show <last-good-commit>:docs/GROWTH_STRATEGY_ROADMAP.md > docs/GROWTH_STRATEGY_ROADMAP.md
```

Rebuilding 31,000 lines by hand would be impossible. git's immutability is a textbook case of protecting "capital = time."

## Lesson 1: constrain scheduled agents to append-only

For large append-only record files (roadmaps, changelogs, ops logs), **never allow an automated agent to full Write**. Allow only tail appends.

| Operation | On a large shared file |
|-----------|------------------------|
| Tail append (anchored) | ✅ safe |
| Local edit on a unique anchor | ⚠️ ok if the anchor is unique |
| Whole-file overwrite (full Write) | ❌ forbidden (source of truncation) |

In practice, restrict the agent's edit tool to "append anchored on a unique tail string." In the very session behind this post, the ROADMAP entry was written **without re-reading any of the 31,364 lines** — anchored on the unique last line and appended (no full read, no full Write).

## Lesson 2: add a push-to-main regression guard

Don't rely on human eyes — **mechanically reject mass deletions** in CI / a pre-receive hook.

```bash
# Example: fail if a tracked file shrinks by more than N lines
THRESHOLD=500
before=$(git show "$BASE:docs/GROWTH_STRATEGY_ROADMAP.md" | wc -l)
after=$(wc -l < docs/GROWTH_STRATEGY_ROADMAP.md)
if [ $((before - after)) -gt $THRESHOLD ]; then
  echo "::error::ROADMAP shrank by $((before - after)) lines — block destructive overwrite"
  exit 1
fi
```

Following an existing regression-guard pattern lets you stop the whole class of "a grown file shrinks by accident" across the repo.

## Lesson 3: archive/split files that grow too large

A single 31,000-line markdown file is risky on every axis — editing, diffing, and blast radius when something goes wrong. Split by period (e.g. `ROADMAP_2026H1.md`) to keep the live file small and shrink the blast radius of any single incident.

## Takeaways

- **Detection**: verify-first (premises as hypotheses → cross-check against git/state) caught the data loss instantly
- **Recovery**: file-level restore from the git last-good commit, ~5 minutes
- **Prevention**: (1) append-only discipline (no full Write), (2) mass-deletion regression guard, (3) archive/split for huge files

Automation trades speed for the risk of a "self-driving destructive operation." Build the safety valve in two layers: a design that **limits the agent to appends only**, and a guard that **mechanically rejects anomalies**.
