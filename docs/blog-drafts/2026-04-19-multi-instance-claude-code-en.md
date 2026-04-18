---
title: "Running 3 Parallel Claude Code Instances to Get $200 of Dev Work for $20/month"
tags: ClaudeCode,AI,buildinpublic,webdev,productivity
published: false
---

# Running 3 Parallel Claude Code Instances to Get $200 of Dev Work for $20/month

## Overview

I build [Jibun Kabushiki Kaisha](https://my-web-app-b67f4.web.app/) — a 200-page Flutter Web SaaS — using Claude Code. On a $20/month plan, I run **3 specialized Claude Code instances in parallel** to achieve roughly 10x the development throughput.

## The Role Assignment System

Each instance has a fixed responsibility:

| Instance | Dedicated Role | Why |
|----------|---------------|-----|
| **VSCode** | UI/design compliance (haiku-4.5) | Fast, cheap, visual tasks |
| **PowerShell** | CI/CD health + blog publishing | Quality-critical, pipeline focus |
| **Windows App** | AI University providers + migrations | Data-heavy, structured work |

## Why Specialization Works

### Problem: Concurrent Pushes Cancel Deploys

Without coordination, all 3 instances push simultaneously:

```
PS push → deploy starts
VSCode push (5s later) → deploy CANCELLED → restart
Win push (3s later) → deploy CANCELLED → restart
→ 20+ minutes later: finally 1 successful deploy
```

This "deploy thrashing" wastes CI minutes and breaks each other's work.

### Solution: Cross-Instance PR Files

Instead of direct communication, instances leave work requests in `docs/cross-instance-prs/`:

```markdown
# docs/cross-instance-prs/20260419_trailing_comma_fix.md

## Target: PowerShell instance
## Task: Fix require_trailing_commas 36 errors
## Reason: PS instance owns CI/CD health (Rule17)
```

VSCode finds a lint issue → records it in cross-instance-pr → PS instance picks it up next session.

## Detecting Parallel Conflicts

```bash
# Check at session start
git log origin/main --oneline -10

# Look for interleaved commits from multiple instances:
# 88e37a2 Merge (conflict resolution)
# f2520c6 (PS#136) 
# c66830d (VSCode#104)
# badccf5 (PS#135)
# → Multiple instances active → watch for ROADMAP merge conflicts
```

## Token Conservation Strategy

On $20/month across 3 instances, every token matters.

### 1. CAVEMAN Communication Mode

A custom Claude Code plugin that compresses responses ~75%:

```
❌ Standard:
"I'll be happy to analyze the current CI failures and provide 
a comprehensive fix. Let me first examine..."

✅ CAVEMAN mode:
"2276 lint errors. dart fix --apply → format → 0 errors. push."
```

### 2. Offload Heavy Research to NotebookLM

| Task | Claude cost | After NotebookLM |
|------|------------|-----------------|
| Read 3+ files simultaneously | ~150K tokens | ~5K tokens |
| Analyze a URL | ~60K tokens | ~2K tokens |
| Competitor research | ~80K tokens | ~3K tokens |

### 3. Role Boundaries Reduce Context Loading

Each instance only loads context relevant to its specialty. The VSCode instance doesn't need to know migration history. The PS instance doesn't need design system knowledge.

## A Typical Day

```
09:00 JST - PS: CI health check + blog dispatch
11:00 JST - VSCode: UI improvements + design token compliance  
14:00 JST - Win: Add AI University providers
16:00 JST - PS: Confirm deploy + write more blog posts
18:00 JST - Win: Migrations + EF cleanup
```

At each session start: `git log origin/main -5` to see what other instances committed.

## Results

- **Throughput**: 3 parallel workstreams from 1 person
- **Cost**: ~$20/month for ~$200 equivalent work
- **Quality**: Each domain improves independently without cross-contamination

## The Key Insight

The $20/month constraint doesn't limit what you can build — it forces you to think about *where* each token should go. Specialization turns a limitation into a feature: each instance is expert at its domain precisely because it never gets distracted by others.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #buildinpublic #AI #productivity
