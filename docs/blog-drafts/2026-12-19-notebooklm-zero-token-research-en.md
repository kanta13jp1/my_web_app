---
title: "Zero-Token Research: Delegating Claude Code's Heaviest Work to NotebookLM"
tags: ai,automation,indiedev,programming
published: true
---

# Zero-Token Research: Delegating Claude Code's Heaviest Work to NotebookLM

The single change that cut my Claude Code token usage by 49%: stop using Claude to read documents. Delegate that work to NotebookLM.

Reading 3 files simultaneously in Claude costs ~150K tokens. The same work in NotebookLM costs ~5K tokens and returns a structured summary. That's a 30x difference.

## The Token Cost Breakdown

| Operation | Claude Cost | After NotebookLM Delegation |
|---|---|---|
| Read 3+ files simultaneously | ~150K tokens | ~5K tokens |
| Analyze a URL | ~60K tokens | ~2K tokens |
| Research 21 competitors | ~80K tokens | ~3K tokens |
| Survey an entire document set | ~100K tokens | ~4K tokens |

Claude Code excels at judgment, integration, and code generation. It's wasteful for retrieval. The goal is to push all retrieval work outside Claude's context.

## Basic Workflow

```bash
# 1. Create a notebook
notebooklm create "Competitor Analysis 2026-Q4"

# 2. Add sources (files / URLs / YouTube)
notebooklm source add "./docs/competitor-reports/2026-10.md"
notebooklm source add "https://example.com/saas-report"

# 3. Query
notebooklm ask "What pricing patterns do the 21 competitors share?"

# 4. Generate artifacts (processed on Google's infrastructure, free)
notebooklm generate slide-deck "Summarize key insights as slides"
notebooklm generate audio "deep dive focusing on key findings" --wait
```

Claude only consumes tokens for the one-line query. NotebookLM handles all the processing.

## Web Deep Research: Autonomous Investigation

```bash
# NotebookLM autonomously searches the web and builds a report
notebooklm source add-research "advanced Flutter Web performance optimization 2026"
notebooklm research wait
notebooklm ask "Summarize the findings"
```

`add-research` lets NotebookLM investigate hundreds of pages autonomously. Claude Code is idle while this runs.

## DBS Framework: Research → Skill Conversion

Don't throw away research findings — convert them into Claude Code skills:

```
D (Direction) = Decision trees, procedures, error recovery → SKILL.md core
B (Blueprints) = Templates, classification rules → support files
S (Solutions) = API calls, deterministic code → scripts
```

Example: the `t1-blog-dispatch` skill in this project was built by researching `blog-publish.yml` behavior in NotebookLM, then applying DBS to create a reusable SKILL.md.

## Monthly Token Reduction

| Month | Claude tokens | Delegated to NotebookLM | Savings |
|---|---|---|---|
| Jan 2026 | 800K | 0K | 0% |
| Feb 2026 | 750K | 150K | 20% |
| Mar 2026 | 500K | 350K | **44%** |
| Apr 2026 | 420K | 400K | **49%** |

The 50% reduction target was hit by April.

## Master Brain: Externalizing Long-Term Memory

NotebookLM also serves as a persistent "Master Brain" across Claude sessions:

```bash
notebooklm use ea6cff25-574d-4b8b-ad72-ab47cf1ed01f  # project notebook
notebooklm source add "./memory/project_20260428.md"  # accumulate session summaries
notebooklm ask "What architecture decisions failed in the past?"
```

Claude's context window resets between sessions. NotebookLM's index doesn't. Decisions, failures, and rationale survive across months.

## The Three Rules

1. **Never read 3+ files in Claude** — pass them to NotebookLM
2. **Never fetch URLs in Claude** — use NotebookLM source add
3. **Append session summaries to Master Brain** — don't discard knowledge

The reframe: Claude Code isn't a research assistant. It's a decision-maker. Give it only what it needs to decide.
