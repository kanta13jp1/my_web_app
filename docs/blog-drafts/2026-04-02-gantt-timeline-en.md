---
title: "Building a Gantt Chart That Beats Notion's Timeline View — Flutter Web + Supabase"
tags: Flutter,Supabase,buildinpublic,projectmanagement,webdev
published: true
---

# Building a Gantt Chart That Beats Notion's Timeline View — Flutter Web + Supabase

## Why Compete With Notion's Timeline

Notion's Timeline view is powerful but has two problems:
1. It's **paid-only** (Team plan+)
2. It has **no critical path analysis**

I'm building [自分株式会社](https://my-web-app-b67f4.web.app/) — an app that replaces 21 SaaS tools including Notion — so I need a Gantt chart that's free *and* has features Notion doesn't.

---

## The 3-Tab Architecture

`GanttTimelinePage` is organized into three tabs:

1. **Projects** — create and select projects
2. **Timeline** — visual Gantt bars for tasks and milestones
3. **Critical Path** — ranking of tasks by latest completion date

---

## Backend: Reusing `app_analytics` as a Generic Storage Table

Rather than creating a `gantt_tasks` table, I store Gantt data in the existing `app_analytics` table using `source` as a discriminator:

```typescript
// POST /functions/v1/gantt-timeline-manager (action: "add_task")
const { error } = await adminClient.from("app_analytics").insert({
  user_id: user.id,
  source: "gantt_task",        // discriminator
  metadata: {
    task_id: crypto.randomUUID(),
    project_id,
    name,
    duration_days,
    start_date,
    status: "pending",
    progress: 0,
  },
});
```

Querying tasks:
```typescript
const { data } = await adminClient
  .from("app_analytics")
  .select("*")
  .eq("user_id", user.id)
  .eq("source", "gantt_task")
  .contains("metadata", { project_id });
```

**Why this works**: `app_analytics` already has `user_id`, `source`, and `metadata` (JSONB). For feature-specific data that doesn't need complex relational queries, this avoids schema migration and new table overhead.

---

## Frontend: Gantt Bars with `LinearProgressIndicator`

Flutter's `LinearProgressIndicator` doubles as a Gantt bar with minimal code:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: progress.clamp(0.0, 1.0),
    minHeight: 12,
    backgroundColor: Colors.grey.shade200,
    valueColor: AlwaysStoppedAnimation<Color>(_statusColor(status)),
  ),
),
```

Status colors:
```dart
Color _statusColor(String status) => switch (status) {
  'done'        => Colors.green,
  'in_progress' => Colors.blue,
  'blocked'     => Colors.red,
  _             => Colors.grey,
};
```

The `ClipRRect` rounds the corners; `minHeight: 12` gives it enough visual weight to read at a glance.

---

## Critical Path Analysis in the Edge Function

The critical path identifies which tasks, if delayed, would delay the entire project. My implementation uses the simplest valid definition: tasks sorted by latest end date.

```typescript
const endDates = [];
for (const [taskId, task] of taskMap) {
  const start = new Date(task.start_date ?? Date.now());
  const duration = task.duration_days ?? 1;
  const end = new Date(start.getTime() + duration * 86400000);
  endDates.push({
    taskId,
    name: task.name,
    endDate: end.toISOString(),
    duration,
  });
}
// Sort: latest end date first = most critical
endDates.sort(
  (a, b) => new Date(b.endDate).getTime() - new Date(a.endDate).getTime()
);
```

This runs server-side in the Edge Function, not in the Flutter client. Keeps the client code thin and makes the logic testable.

---

## The `avoid_dynamic_calls` Trap

`supabase.functions.invoke()` returns `dynamic`. Direct property access triggers the `avoid_dynamic_calls` lint rule:

```dart
// FAILS flutter analyze
_tasks = (taskRes.data?['tasks'] as List?) ?? [];

// PASSES: cast to Map first
final taskData = taskRes.data as Map<String, dynamic>?;
_tasks = (taskData?['tasks'] as List?) ?? [];
```

Always cast `FunctionResponse.data` to `Map<String, dynamic>?` before accessing properties. One extra line prevents a class of runtime errors.

---

## Feature Comparison vs. Notion

| Feature | Notion Timeline | 自分株式会社 |
|---------|----------------|------------|
| Gantt bars | ✅ | ✅ |
| Milestones | ✅ | ✅ |
| Critical path analysis | ❌ | ✅ |
| Free tier | ❌ (paid only) | ✅ |
| Integrated with notes/tasks | ❌ (separate DB) | ✅ |

The critical path tab is the differentiator. Notion shows you when tasks are scheduled; we show you which tasks you can't afford to slip.

---

## Key Takeaways

1. **`app_analytics` + `source` discriminator** avoids schema migrations for feature-specific data
2. **`LinearProgressIndicator` as Gantt bar** — Flutter's built-in widgets go further than you'd expect
3. **Critical path server-side** — move sorting/analysis to the Edge Function, keep the client rendering only
4. **Always cast `dynamic` from EF responses** — `avoid_dynamic_calls` is enforced by `flutter analyze`

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #projectmanagement #webdev
