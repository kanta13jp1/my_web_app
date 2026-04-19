---
title: "Building an MS Project-Style Gantt Chart in Flutter Web — CustomPaint with Synchronized Scrolling"
tags: Flutter,buildinpublic,UI,webdev
published: false
---

# Building an MS Project-Style Gantt Chart in Flutter Web

## The Goal

Visualize WBS (Work Breakdown Structure) progress with a synchronized task list on the left and a scrollable timeline on the right — like MS Project, but in Flutter Web.

## Architecture

```
Row(
  children: [
    // Left pane: task names and assignees (fixed width)
    SizedBox(width: 300, child: TaskListPane()),
    // Right pane: timeline bars (horizontally scrollable)
    Expanded(child: TimelinePane()),
  ],
)
```

Two `ScrollController` instances linked together keep vertical scroll synchronized between panes.

## Implementation

### Synchronized Scrolling

```dart
class _GanttChartPageState extends State<GanttChartPage> {
  final _leftVertical = ScrollController();
  final _rightVertical = ScrollController();

  @override
  void initState() {
    super.initState();
    _leftVertical.addListener(() {
      if (_rightVertical.offset != _leftVertical.offset) {
        _rightVertical.jumpTo(_leftVertical.offset);
      }
    });
    _rightVertical.addListener(() {
      if (_leftVertical.offset != _rightVertical.offset) {
        _leftVertical.jumpTo(_rightVertical.offset);
      }
    });
  }
}
```

### Drawing Gantt Bars with CustomPaint

```dart
class GanttBarPainter extends CustomPainter {
  final List<WbsTask> tasks;
  final DateTime startDate;
  final double dayWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final y = i * 40.0 + 8;
      final startX = task.startDate.difference(startDate).inDays * dayWidth;
      final barWidth = task.duration.inDays * dayWidth;

      // Background bar
      paint.color = _progressColor(task.progressRate).withAlpha(80);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y, barWidth, 24),
          const Radius.circular(4),
        ),
        paint,
      );

      // Progress fill
      paint.color = _progressColor(task.progressRate);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y, barWidth * task.progressRate / 100, 24),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  Color _progressColor(int progress) {
    if (progress >= 100) return const Color(0xFF4CAF50); // done: green
    if (progress >= 50) return const Color(0xFFFF9800);  // in progress: orange
    return const Color(0xFFFF5722);                       // behind: red
  }

  @override
  bool shouldRepaint(GanttBarPainter old) =>
      old.tasks != tasks || old.startDate != startDate;
}
```

### WbsTask Model

```dart
class WbsTask {
  final String id;
  final String title;
  final String? assignee;
  final DateTime startDate;
  final Duration duration;
  final int progressRate; // 0-100
  final List<String> dependencies;
}
```

### Supabase Schema

```sql
CREATE TABLE wbs_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  progress_rate int DEFAULT 0 CHECK (progress_rate BETWEEN 0 AND 100),
  dependencies uuid[],
  user_id uuid REFERENCES auth.users(id)
);
```

## Gotchas

### shouldRepaint performance

Returning `true` always causes per-frame repaints. Check if data actually changed:

```dart
@override
bool shouldRepaint(GanttBarPainter old) =>
    old.tasks != tasks || old.startDate != startDate;
```

### Alignment between header and bars

The date header (month/day labels) and the actual bar positions must use the same `startDate` and `dayWidth` constant. Compute both in the parent widget and pass them down.

## Conclusion

Flutter Web's `CustomPaint` handles complex visualizations that existing widgets can't. For Gantt charts with custom grid layouts, painting from scratch gives you full control — and the performance is fine for typical WBS sizes (< 200 tasks).

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #CustomPaint #buildinpublic #WBS
