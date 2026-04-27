---
title: "WBS + AI: How I Automated Task Management Across 12 Parallel AI Instances"
tags: ai,postgresql,automation,indiedev
published: false
---

# WBS + AI: How I Automated Task Management Across 12 Parallel AI Instances

Running 12 AI instances in parallel — 10 Claude Code + 2 Codex CLI — sounds impressive until you realize that task tracking becomes its own full-time job. If humans manually update a WBS board for 12 agents, the humans become the bottleneck.

The solution: **make the WBS itself readable and writable by the AI instances**.

## The Problem: Parallel Agents Without Coordination

```
Claude Code × 10 (VSCode / Win / PS#1-6 / Web / Mobile)
+ Codex CLI × 2
= 12 instances updating progress simultaneously
```

Without coordination:
- Instances forget to report completion
- Two instances pick up the same task
- The true state of progress becomes unknowable

## Architecture: WBS-as-a-Service

```
Each instance
  → tools-hub Edge Function (wbs.priority_for_instance / wbs.update_progress)
  → wbs_tasks table (PostgreSQL / Supabase)
  → GHA wbs-staleness-audit cron (every 24h)
  → MEMORY.md + NotebookLM Master Brain
```

## Schema Design

```sql
CREATE TABLE wbs_tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  instance    TEXT NOT NULL,  -- 'vscode' | 'win' | 'ps1' .. 'ps6' | 'web' | 'mobile'
  status      TEXT NOT NULL DEFAULT 'pending',
  priority    INT  NOT NULL DEFAULT 5,
  depends_on  UUID[] DEFAULT '{}',
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Top-5 tasks per instance
CREATE OR REPLACE FUNCTION wbs_priority_for_instance(p_instance TEXT)
RETURNS SETOF wbs_tasks AS $$
  SELECT * FROM wbs_tasks
  WHERE instance = p_instance
    AND status = 'pending'
  ORDER BY priority DESC, updated_at ASC
  LIMIT 5;
$$ LANGUAGE sql;
```

## Edge Function: WBS Actions in tools-hub

```typescript
// supabase/functions/tools-hub/index.ts
case 'wbs.priority_for_instance': {
  const { instance } = body.params;
  const { data } = await supabase
    .rpc('wbs_priority_for_instance', { p_instance: instance });
  return json({ tasks: data });
}

case 'wbs.update_progress': {
  const { task_id, status } = body.params;
  await supabase
    .from('wbs_tasks')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', task_id);
  return json({ ok: true });
}
```

## Mandatory Injection: inject-rules.txt

The `[WBS-SYNC]` rule is injected into every instance's context via a `UserPromptSubmit` hook at session start:

```text
[WBS-SYNC]: Call wbs.priority_for_instance at session start.
Mark completed tasks as done immediately via wbs.update_progress.
Skipping this is detectable by the GHA wbs-staleness-audit cron.
```

The key insight: **don't ask agents to be disciplined — make indiscipline detectable**.

## GHA Staleness Audit: Automatic Alerts After 24h

```yaml
# .github/workflows/wbs-staleness-audit.yml
on:
  schedule:
    - cron: '0 */24 * * *'

jobs:
  audit:
    steps:
      - name: Check stale in_progress tasks
        run: |
          STALE=$(psql "$DATABASE_URL" -t -c "
            SELECT title, instance, updated_at
            FROM wbs_tasks
            WHERE status = 'in_progress'
              AND updated_at < NOW() - INTERVAL '24 hours'
          ")
          if [ -n "$STALE" ]; then
            gh issue create \
              --title "WBS staleness detected" \
              --body "$STALE"
          fi
```

## Results

Before: instances occasionally created duplicate migration files → merge conflicts  
After: `depends_on` array declares dependencies → automatic serialization

| Metric | Before | After |
|---|---|---|
| Task duplication rate | ~40% | **3%** |
| Progress update lag | avg 4 hours | **immediate** |
| Human manual WBS time | 2h/week | **15min/week** |

## Three Design Lessons

**1. Have agents declare state, not infer it.**  
Calling `wbs.priority_for_instance` at session start means the instance *knows* its tasks. Not guessing, not remembering — reading from the authoritative source.

**2. Audit via GHA, not via human review.**  
Stale tasks generate GitHub Issues automatically. Humans only handle exceptions. The system catches what humans miss.

**3. `null` means unassigned; `all` is a trap.**  
If you try `UPDATE wbs_tasks SET instance='codex1' WHERE instance='all'`, you hit a UNIQUE violation if `codex1` rows already exist. Use `null` for "unassigned" — it's semantically clean and avoids conflicts.

## The Pattern That Scales

The same pattern applies to any multi-agent system:

```text
1. Give agents a single read endpoint for their queue
2. Give agents a single write endpoint for status updates
3. Run an auditor that detects stalls and surfaces them
4. Keep humans in the exception-handling path only
```

The goal isn't to eliminate human oversight — it's to make oversight efficient enough that humans can actually manage 12 parallel workstreams.
