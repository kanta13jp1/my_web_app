---
title: "AI-Powered Task Prioritization: How Jibun Kaisha's WBS System Works"
tags: productivity,ai,saas,project-management
published: false
---

# AI-Powered Task Prioritization: How Jibun Kaisha's WBS System Works

## The Real Problem with Task Management

Notion, Trello, Asana, Linear, Jira — the tool list keeps growing. The problem isn't the tools. It's that **organizing tasks has become its own task**: entering, categorizing, prioritizing, updating progress. That overhead alone eats 30 minutes a day.

Jibun Kaisha's WBS system addresses this by making AI responsible for the organizational overhead — not the human.

---

## WBS Design Philosophy

### Six-Department Balance

Jibun Kaisha operates as a six-department company:

| Department | Category | Examples |
|------------|----------|---------|
| HR | business-hr | Hiring, self-development |
| Finance | business-finance | P/L, investor relations |
| Legal | business-legal | Registration, contracts |
| Marketing | business-marketing | SEO, SNS, PR |
| Product | business-product | Feature dev, UX |
| Sales | business-sales | B2B deals, LTV |

Tasks are tagged to one of these categories. The system surfaces imbalance — if 80% of tasks are Product and nothing is HR, that's a signal.

### Instance-Based Task Distribution

Ten AI instances (VSCode/Windows/PowerShell #1–6/Web/Mobile) each have assigned tasks:

```
instance: ps2
  → SEO 50-article plan (business-marketing)
  → T-1 blog dispatch routine

instance: ps4
  → 190-company competitor monitoring
  → jp_strength scoring
```

At session start, each instance queries `wbs.priority_for_instance` and gets the top 5 tasks for that specific context.

---

## What the AI Assistant Actually Does

### 1. Priority Extraction

```json
{
  "action": "wbs.priority_for_instance",
  "instance": "ps2"
}
// Returns: top 5 tasks sorted by rescue_score
```

**rescue_score** formula:

```
rescue_score =
  (overdue_days × 40) +
  (stale_days × 20) +
  (priority_rank × 25) +
  (progress_pct × 15)
```

Tasks that are overdue or haven't been updated in 3+ days automatically surface to the top. No manual re-sorting needed.

### 2. Automatic Progress Logging

At session start and end:

```json
{
  "action": "wbs.update_progress",
  "id": "task-uuid",
  "progress": 75,
  "status": "in_progress",
  "session": "PS#2 S46: SEO Phase2 #18+#19 completed / commit abc123"
}
```

Every session records: what changed, how far along, which instance did it, and what commit corresponds to the work.

### 3. Cross-Instance Handoff PRs

When one instance needs to pick up work from another's lane, the system auto-generates a handoff document:

```
docs/cross-instance-prs/20260426_ps2_to_vscode_seo_review.md
```

---

## Implementation: Supabase Schema

```sql
CREATE TABLE wbs_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  category TEXT NOT NULL,       -- business-hr, business-finance, etc.
  status TEXT DEFAULT 'pending', -- pending, in_progress, completed, blocked
  progress INTEGER DEFAULT 0,    -- 0–100
  priority TEXT DEFAULT 'medium', -- low, medium, high, critical
  instance TEXT,                 -- assigned AI instance
  owner_instance TEXT,           -- owner (usually same as instance)
  end_date DATE,                 -- deadline
  recovery_plan TEXT DEFAULT '', -- plan when blocked
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### RLS Policy

```sql
-- Regular users see only their tasks
CREATE POLICY "users can view own tasks"
  ON wbs_tasks FOR SELECT
  USING (auth.uid() = owner_id);

-- service_role (Edge Functions) has full access
CREATE POLICY "service role all access"
  ON wbs_tasks FOR ALL
  USING (auth.role() = 'service_role');
```

---

## Session Flow in Practice

```
1. Session starts → query wbs.priority_for_instance
2. Pick top rescue_score task
3. Set status = in_progress
4. Do the work
5. Update progress/status + log session note with commit hash
```

### When Blocked

```
User: "I'm stuck on the company registration step"
AI:  → wbs.list_tasks(category="business-legal", status="blocked")
     → Finds "司法書士・税理士契約" with empty recovery_plan
     → "Should I log 'Contact a judicial scrivener referral service' as the recovery plan?"
```

The AI has full DB context, so suggestions are specific — not generic productivity advice.

---

## Comparison: Notion, Asana, vs WBS

| Feature | Notion | Asana | Jibun Kaisha WBS |
|---------|--------|-------|-----------------|
| Customization | ◎ | ○ | △ (opinionated) |
| AI priority scoring | △ | △ | ◎ (rescue_score) |
| Multi-instance distribution | ✗ | ✗ | ◎ |
| Direct DB integration | ○ (limited) | ✗ | ◎ (Supabase) |
| Monthly cost | $16+ | $10+ | $0 (self-built) |

Notion is flexible but weak on AI integration. Jibun Kaisha's WBS is purpose-built for one use case: a solo founder working with multiple AI agents in parallel.

---

## What This Changes

The traditional task management cycle:
```
Human decides priority → Human updates status → Human checks what's next
```

The AI-assisted cycle:
```
AI surfaces priority → Human acts → AI logs progress → repeat
```

The cognitive overhead of "what should I work on and in what order" moves to the AI. The human focuses on the work itself.

---

## Summary

- The real task management problem is **organizational overhead**, not task tracking
- **rescue_score** surfaces neglected and overdue work automatically
- **Instance-based distribution** lets multiple AI agents work in parallel without coordination conflicts
- **Supabase DB integration** gives the AI real-time context, enabling specific (not generic) suggestions

If you've tried every task management tool and still feel behind, the missing piece might not be a better tool — it's AI doing the organizing so you only do the executing.

---

## Related Posts

- [Real Costs of a Multi-AI Workflow](./2026-07-25-multi-ai-workflow-real-costs-en.md)
- [Supabase Edge Functions + AI Cost Breakdown](./2026-08-22-supabase-edge-functions-ai-cost-en.md)
- [AI University: 230 Providers Guide](./2026-08-15-ai-university-200-providers-guide-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
