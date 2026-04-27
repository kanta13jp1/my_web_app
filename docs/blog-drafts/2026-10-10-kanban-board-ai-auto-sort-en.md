---
title: "AI-Sorted Kanban: Delegating Priority Decisions to a Score"
tags: productivity,ai,project-management,saas
published: true
---

# AI-Sorted Kanban: Delegating Priority Decisions to a Score

## Who Decides the Order?

Trello, Notion, Linear — every kanban tool assumes a human will decide the order. Drag to reprioritize. Add labels. Apply filters.

That maintenance work is not the actual job. It's overhead.

Jibun Kaisha's WBS kanban has AI decide the order automatically.

---

## rescue_score: The Sort Engine

The `rescue_score` introduced in the WBS task management post drives the kanban sort:

```
rescue_score =
  (overdue_days × 40) +    ← deadline passed = urgent
  (stale_days × 20) +      ← not updated in 3+ days = at risk
  (priority_rank × 25) +   ← high priority = important
  (progress_pct × 15)      ← started = continue momentum
```

All tasks are scored and displayed in descending order. No human reordering needed.

---

## Implementation: Supabase View + Flutter

### Supabase Side (Pre-sorted View)

```sql
CREATE VIEW wbs_kanban AS
SELECT
  id,
  title,
  status,
  progress,
  priority,
  instance,
  end_date,
  updated_at,
  (
    GREATEST(0, EXTRACT(DAY FROM (NOW() - end_date::TIMESTAMPTZ))) * 40 +
    GREATEST(0, EXTRACT(DAY FROM (NOW() - updated_at))) * 20 +
    CASE priority
      WHEN 'critical' THEN 100
      WHEN 'high'     THEN 75
      WHEN 'medium'   THEN 50
      WHEN 'low'      THEN 25
      ELSE 0
    END * 25 / 100 +
    progress * 15 / 100
  ) AS rescue_score
FROM wbs_tasks
WHERE status != 'completed'
ORDER BY rescue_score DESC;
```

### Flutter Side (Kanban UI)

```dart
class KanbanBoard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(kanbanTasksProvider);

    return tasks.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Text('Error: $err'),
      data: (taskList) => Row(
        children: KanbanLane.values.map((lane) =>
          KanbanColumn(
            lane: lane,
            // Already sorted by rescue_score — no additional sort needed
            tasks: taskList.where((t) => t.status == lane.name).toList(),
          ),
        ).toList(),
      ),
    );
  }
}
```

---

## Auto-Classification: Lane Assignment

### Heuristic Lane Assignment

```typescript
function wbsTaskLane(task: Record<string, unknown>): string {
  const status = String(task.status ?? "pending");
  const progress = Number(task.progress ?? 0);

  if (status === "completed") return "done";
  if (status === "blocked") return "blocked";
  if (progress > 0 && progress < 100) return "in_progress";
  if (status === "in_progress") return "in_progress";
  return "todo";
}
```

### Claude AI Recommendation

At session start, AI reviews the full WBS and recommends the single best task to start:

```typescript
const systemPrompt = `
You are a productivity coach.
Review the WBS task list below (sorted by rescue_score, descending).
Recommend one task to tackle this session and explain why.

Task list:
${tasksJson}

Selection criteria: deadline proximity, importance, continuity from last session, instance fit
`;
```

---

## Swimming Lanes: Instance-Level Filtering

Ten AI instances work in parallel. The kanban filters to the current instance's tasks while preserving rescue_score sort:

```dart
final filteredTasks = allTasks
  .where((t) => t.instance == currentInstance)
  .toList();
// rescue_score sort is maintained within the filtered set
```

Open PS#2 → see only PS#2 tasks. Open VSCode instance → see only VSCode tasks.

---

## Comparison: Trello, Linear, WBS Kanban

| Feature | Trello | Linear | Jibun Kaisha WBS Kanban |
|---------|--------|--------|------------------------|
| Sort method | Manual D&D | Priority labels | rescue_score (automatic) |
| AI priority recommendation | ✗ | △ | ◎ |
| Instance-level filtering | ✗ | Project-level | ◎ (10 instances) |
| Direct DB connection | ✗ (API) | ✗ (API) | ◎ (Supabase) |
| Webhook integrations | ◎ | ◎ | △ |
| Gantt view | △ | ◎ | ◎ |
| Monthly cost | $5+ | $8+ | $0 |

---

## Design Principles for AI-Sorted Kanban

Three things that matter when AI decides the order:

**1. Score Transparency**

Users need to understand why a task ranks where it does. Show the rescue_score breakdown. Opacity breeds distrust.

**2. Manual Override Must Exist**

AI sort isn't always right. "I know today needs to be X" is a valid human decision. Support pinning a task to the top for the current session.

**3. Long-Horizon Task Protection**

Tasks with distant deadlines score low naturally. A task that's critical but 6 months away can get buried indefinitely. Build periodic review (e.g., end-of-session scan) into the workflow to surface these.

---

## Summary

- Reordering is something AI does well and humans find draining
- rescue_score unifies deadline, staleness, priority, and progress into a single sortable number
- Supabase views deliver pre-sorted data; Flutter focuses on rendering
- Transparency and manual override are non-negotiable for adoption

The point of a kanban board is to know, at a glance, what to work on next. Delegating that judgment to a score frees humans to do the actual work.

---

## Related Posts

- [AI-Powered WBS Task Management](./2026-09-12-wbs-task-management-ai-assistant-en.md)
- [Monitoring 190 Competitors Automatically](./2026-09-26-competitor-monitoring-190-companies-en.md)
- [Supabase Edge Functions + AI Cost Breakdown](./2026-08-22-supabase-edge-functions-ai-cost-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
