---
title: "Managing Technical Debt in Indie Dev: Which Debt to Keep, Which to Pay"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Managing Technical Debt in Indie Dev: Which Debt to Keep, Which to Pay

Trying to eliminate all technical debt stops you from shipping. The goal is
strategic debt management — borrow wisely, repay what blocks you.

## Debt Classification

```
Strategic debt (OK to carry)
  ├── Placeholder code before MVP validation
  ├── Isolated modules you can refactor later
  └── Performance trade-offs acceptable at low user count

Blocking debt (must repay)
  ├── Tightly coupled code that's impossible to test
  ├── Structure that causes recurring bugs
  └── Code that raises cognitive load (including future-you)
```

## Making Debt Visible: TODO / FIXME

```dart
// Explicitly annotate debt with a timeline
// TODO(2028-Q2): Migrate to Supabase RPC after Edge Function refactor
Future<List<Task>> getTasksHack(String userId) async {
  // FIXME: N+1 query — must convert to RPC when row count grows
  final tasks = await supabase.from('tasks').select().eq('user_id', userId);
  return tasks.map(Task.fromJson).toList();
}
```

**Quantify debt in CI**:

```yaml
# .github/workflows/debt-audit.yml
- name: Count TODOs and FIXMEs
  run: |
    TODO_COUNT=$(grep -r 'TODO\|FIXME' lib/ --include='*.dart' | wc -l)
    echo "Technical debt items: $TODO_COUNT"
    echo "debt_count=$TODO_COUNT" >> $GITHUB_OUTPUT
```

## Prioritizing Refactors

```
High priority:
  - Areas with recurring bugs (has open Issues)
  - High-churn code that's hard to understand
  - Structures that block new features every time

Low priority:
  - Stable code that never changes
  - Working code covered by passing tests
  - Internal details invisible from outside
```

## Incremental Refactoring: Strangler Fig Pattern

Never rewrite large modules all at once. Run old and new code in parallel,
then cut over incrementally.

```dart
// Before: direct Supabase calls scattered across widgets
class TaskPage extends StatefulWidget {
  Future<void> _loadTasks() async {
    final data = await supabase.from('tasks').select();
    setState(() => _tasks = data.map(Task.fromJson).toList());
  }
}

// Step 1: introduce a Repository layer (run in parallel)
class TaskRepository {
  Future<List<Task>> getAll(String userId) async {
    final data = await supabase
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }
}

// Step 2: new pages use the new layer
// Step 3: delete old code once tests pass
```

## The 20% Rule

Allocate **20% of each week's work** to paying down technical debt.

```
Mon–Thu: new features (80%)
Friday:  refactors, test coverage, TODO cleanup (20%)
```

This prevents debt from compounding while still keeping velocity high.

## Automated Weekly Reminder via GHA

```yaml
# .github/workflows/weekly-debt-reminder.yml
on:
  schedule:
    - cron: '0 9 * * MON'

jobs:
  remind:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: List top debt items
        run: |
          grep -rn 'FIXME\|TODO.*Q[1-4]' lib/ --include='*.dart' | head -10
```

## Summary

```
Classify     → Strategic (keep) vs Blocking (repay now)
Visualize    → TODO/FIXME with deadlines + CI quantification
Prioritize   → recurring bugs > high-churn > feature blockers
Rhythm       → 20% of weekly work on debt repayment
```

Treat technical debt like managed borrowing. Zero-debt isn't the goal —
sustainable debt is.
