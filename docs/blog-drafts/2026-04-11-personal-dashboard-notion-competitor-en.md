---
title: "Building a Personal KPI Dashboard in Flutter Web: Bar Charts Without a Chart Library"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# Building a Personal KPI Dashboard in Flutter Web: Bar Charts Without a Chart Library

## Why No Chart Library

[自分株式会社](https://my-web-app-b67f4.web.app/) keeps external packages minimal for two reasons:
1. Flutter Web's initial bundle size — every package adds to the WASM/JS payload
2. `flutter analyze 0 errors` maintenance — external packages drag in deprecated APIs

Instead: `FractionallySizedBox` + standard widgets.

---

## Bar Chart with `FractionallySizedBox`

```dart
Widget _barChartSection(
  String title, IconData icon, Color color,
  List<Map<String, dynamic>> data, String key, int maxVal,
) {
  return Column(
    children: [
      Row(children: [Icon(icon, color: color), Text(title)]),
      SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((day) {
            final val = (day[key] as num?)?.toInt() ?? 0;
            final heightRatio = maxVal > 0 ? val / maxVal : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (val > 0) Text(val.toString(),
                      style: TextStyle(color: color, fontSize: 9)),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightRatio.clamp(0.02, 1.0),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(day['date'] as String? ?? '',
                      style: const TextStyle(fontSize: 9)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}
```

Key technique: `FractionallySizedBox(heightFactor: heightRatio)` converts a 0.0–1.0 ratio to a proportional height. `clamp(0.02, 1.0)` ensures zero-value days still render a tiny sliver instead of nothing.

---

## KPI Card Grid: `GridView.count` Inside a Scroll View

```dart
GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),  // critical
  childAspectRatio: 1.5,
  children: [
    _kpiCard('Notes',         totalNotes.toString(),     Icons.note_alt,             Color(0xFF7C3AED)),
    _kpiCard('Tasks Done',    tasksCompleted.toString(), Icons.task_alt,              Color(0xFF059669)),
    _kpiCard('Focus Hours',   '${focusHours}h',          Icons.timer,                Color(0xFFDC2626)),
    _kpiCard('Habit Streak',  '${habitStreak}d',         Icons.local_fire_department, Color(0xFFF59E0B)),
  ],
)
```

`shrinkWrap: true` + `NeverScrollableScrollPhysics()` is the standard pattern for embedding a `GridView` inside a `SingleChildScrollView`. Without `NeverScrollableScrollPhysics`, the grid intercepts scroll gestures and the outer scroll view stops responding.

`childAspectRatio` controls card proportions — reduce it (1.5 → 1.3) if card content is tall.

---

## Edge Function with Fallback

The `personal-dashboard` Edge Function may not be deployed yet — the UI ships first:

```dart
try {
  final res = await _supabase.functions.invoke(
    'personal-dashboard',
    body: {'action': 'get_overview'},
  );
  final data = res.data as Map<String, dynamic>?;
  setState(() {
    _kpiData = data?['kpi'] as Map<String, dynamic>? ?? {};
    _weeklyActivity = (data?['weekly'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
  });
} catch (_) {
  // EF not yet deployed — show zeros
  setState(() {
    _kpiData = _buildFallbackKpi();
    _weeklyActivity = _buildFallbackWeekly();
  });
}
```

**Pattern**: UI ships with a fallback. Backend connects when ready. No blocking on backend availability.

---

## `withValues(alpha:)` Replaces `withOpacity()`

```dart
// DEPRECATED (Flutter 3.26+)
color: color.withOpacity(0.12),

// CORRECT
color: color.withValues(alpha: 0.12),
```

`flutter analyze` catches this as `deprecated_member_use`. Do a project-wide replace when you see it — there are usually many instances.

---

## What "Competing with Notion's Dashboard" Means

Notion 3.4 added AI-generated KPI dashboards. The key differentiator in a personal app: the data is already in your system (notes, tasks, focus sessions, habits) — no integration needed.

The Flutter implementation is ~200 lines of widget code. The Edge Function aggregates from 4 tables (`notes`, `tasks`, `focus_sessions`, `habit_logs`) and returns a single JSON object. Flutter renders it.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
